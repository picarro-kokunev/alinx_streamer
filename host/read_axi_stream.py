#!/usr/bin/env python3
"""
Read samples from the alinx_streamer XDMA AXI-Stream path.

Hardware (design_1):
  Host PCIe ──► xdma_0 (AXI Stream mode, Gen2 x2, 64-bit @ 125 MHz)
                  │
                  ├─ c2h_streamer_0 ──► S_AXIS_C2H_0  (memory sequence source)
                  ├─ h2c_axis_sink_* ◄── M_AXIS_H2C_* (discard)
                  └─ M_AXI_LITE
                       ├─ control BRAM  (4 KiB @ 0x0000)
                       └─ pattern BRAM  (4 KiB @ 0x1000)

Control BRAM register map:
  0x00 CTRL [0]=start   0x04 LENGTH   0x08 STATUS   0x0C BEAT_CNT
  0x10 SEQ_LEN          0x14 REPEAT
  Total transfer = SEQ_LEN * REPEAT when REPEAT != 0; else LENGTH.

Pattern BRAM (@ 0x1000): host-writable sequence played by c2h_mem_source
and wrapped every SEQ_LEN bytes for REPEAT periods.

Host arming (ARM_ON_C2H=0 in bitstream): open C2H read first, then write
SEQ_LEN/REPEAT/LENGTH and pulse CTRL. Sizes must be multiples of 8.

Device nodes (Xilinx dma_ip_drivers xdma):
  /dev/xdma0_h2c_{0,1}   host → card (AXIS)
  /dev/xdma0_c2h_{0,1}   card → host (AXIS)
  /dev/xdma0_user        AXI-Lite BAR (BRAMs)
"""

from __future__ import annotations

import argparse
import mmap
import os
import struct
import sys
import threading
import time
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

# AXI Stream beat width from XDMA IP configuration
AXIS_BYTES_PER_BEAT = 8  # 64-bit TDATA
CTRL_BRAM_SIZE = 4096
PATTERN_BRAM_BASE = 0x1000
PATTERN_BRAM_SIZE = 4096
USER_BAR_SIZE = PATTERN_BRAM_BASE + PATTERN_BRAM_SIZE  # 8 KiB mapped window
# Stream control register offsets (see stream_ctrl_regs.v)
REG_CTRL     = 0x00
REG_LENGTH   = 0x04
REG_STATUS   = 0x08
REG_BEAT_CNT = 0x0C
REG_SEQ_LEN  = 0x10
REG_REPEAT   = 0x14
DEFAULT_DEVICE = 0
DEFAULT_CHANNEL = 0


def device_path(kind: str, device: int = DEFAULT_DEVICE, channel: int = 0) -> Path:
    """Build an XDMA char-device path, e.g. /dev/xdma0_c2h_0."""
    if kind == "user":
        return Path(f"/dev/xdma{device}_user")
    if kind in ("h2c", "c2h"):
        return Path(f"/dev/xdma{device}_{kind}_{channel}")
    raise ValueError(f"unknown device kind: {kind}")


def require_device(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Load the Xilinx xdma driver and confirm "
            f"lspci -d 10ee:7022 / ls /dev/xdma*"
        )


def require_axis_aligned(nbytes: int, what: str = "size") -> int:
    """Require a positive multiple of AXIS beat size; return nbytes unchanged."""
    if nbytes < AXIS_BYTES_PER_BEAT or nbytes % AXIS_BYTES_PER_BEAT:
        raise ValueError(
            f"{what} must be a multiple of {AXIS_BYTES_PER_BEAT} and >= "
            f"{AXIS_BYTES_PER_BEAT} (got {nbytes})"
        )
    return nbytes


def dump_stream_status(device: int = DEFAULT_DEVICE) -> str:
    """Read STATUS/BEAT_CNT for hang diagnosis."""
    try:
        with UserBar(device) as bar:
            status = bar.read_u32(REG_STATUS)
            beats = bar.read_u32(REG_BEAT_CNT)
            length = bar.read_u32(REG_LENGTH)
            seq_len = bar.read_u32(REG_SEQ_LEN)
            repeat = bar.read_u32(REG_REPEAT)
        return (
            f"STATUS=0x{status:08X} (busy={status & 1} done={(status >> 1) & 1}) "
            f"BEAT_CNT={beats} LENGTH={length} SEQ_LEN={seq_len} REPEAT={repeat}"
        )
    except OSError as exc:
        return f"(could not read status: {exc})"


def align_down(nbytes: int, align: int = AXIS_BYTES_PER_BEAT) -> int:
    return nbytes - (nbytes % align)


def read_exact(fd: int, nbytes: int, timeout_s: Optional[float] = None) -> bytes:
    """Read exactly nbytes from an open fd (blocking; optional soft timeout)."""
    chunks: List[bytes] = []
    remaining = nbytes
    deadline = None if timeout_s is None else time.monotonic() + timeout_s
    while remaining > 0:
        if deadline is not None and time.monotonic() > deadline:
            got = nbytes - remaining
            raise TimeoutError(f"timed out after {got}/{nbytes} bytes from fd {fd}")
        # Prefer large reads; XDMA completes when the transfer descriptor finishes
        chunk = os.read(fd, remaining)
        if not chunk:
            got = nbytes - remaining
            raise EOFError(f"short read: got {got}/{nbytes} bytes (EOF)")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def write_exact(fd: int, data: bytes) -> None:
    view = memoryview(data)
    while view:
        n = os.write(fd, view)
        if n == 0:
            raise OSError("write returned 0")
        view = view[n:]


def parse_beats(data: bytes, dtype: str = "u64") -> Sequence:
    """
    Interpret raw C2H bytes as AXI-Stream beats.

    dtype:
      u64  — one uint64 little-endian per 64-bit beat (default)
      u32  — two uint32 LE per beat
      i16  — four int16 LE per beat
      raw  — return bytes unchanged
    """
    if dtype == "raw":
        return data
    if len(data) % AXIS_BYTES_PER_BEAT:
        raise ValueError(
            f"buffer length {len(data)} is not a multiple of "
            f"{AXIS_BYTES_PER_BEAT}-byte AXIS beat"
        )
    try:
        import numpy as np
    except ImportError:
        np = None

    fmt = {
        "u64": ("<Q", 8, None if np is None else "<u8"),
        "u32": ("<I", 4, None if np is None else "<u4"),
        "i16": ("<h", 2, None if np is None else "<i2"),
    }
    if dtype not in fmt:
        raise ValueError(f"unsupported dtype {dtype!r}; use u64, u32, i16, or raw")
    struct_fmt, _itemsize, np_dtype = fmt[dtype]
    if np is not None and np_dtype is not None:
        return np.frombuffer(data, dtype=np_dtype)
    count = len(data) // struct.calcsize(struct_fmt)
    return struct.unpack(f"<{count}{struct_fmt[-1]}", data)


def make_test_payload(nbytes: int, pattern: str = "count") -> bytes:
    """Host→card test pattern for loopback (multiple of 8 bytes)."""
    nbytes = align_down(nbytes)
    if nbytes <= 0:
        raise ValueError("nbytes must be >= 8")
    if pattern == "count":
        # Each beat: ascending 64-bit counter
        beats = nbytes // 8
        return struct.pack(f"<{beats}Q", *range(beats))
    if pattern == "ramp16":
        # Four int16 samples per beat: 0,1,2,... wrapping
        n = nbytes // 2
        return struct.pack(f"<{n}H", *[(i & 0xFFFF) for i in range(n)])
    if pattern == "zeros":
        return bytes(nbytes)
    if pattern == "ff":
        return b"\xff" * nbytes
    raise ValueError(f"unknown pattern {pattern!r}")


def read_c2h(
    nbytes: int,
    device: int = DEFAULT_DEVICE,
    channel: int = DEFAULT_CHANNEL,
    timeout_s: Optional[float] = None,
) -> bytes:
    """Read nbytes from S_AXIS_C2H via /dev/xdmaN_c2h_M."""
    nbytes = align_down(nbytes)
    path = device_path("c2h", device, channel)
    require_device(path)
    fd = os.open(path, os.O_RDONLY)
    try:
        return read_exact(fd, nbytes, timeout_s=timeout_s)
    finally:
        os.close(fd)


def write_h2c(
    data: bytes,
    device: int = DEFAULT_DEVICE,
    channel: int = DEFAULT_CHANNEL,
) -> None:
    """Write bytes to M_AXIS_H2C via /dev/xdmaN_h2c_M."""
    if len(data) % AXIS_BYTES_PER_BEAT:
        raise ValueError("H2C payload must be a multiple of 8 bytes")
    path = device_path("h2c", device, channel)
    require_device(path)
    fd = os.open(path, os.O_WRONLY)
    try:
        write_exact(fd, data)
    finally:
        os.close(fd)


def loopback_transfer(
    nbytes: int,
    device: int = DEFAULT_DEVICE,
    channel: int = DEFAULT_CHANNEL,
    pattern: str = "count",
    timeout_s: float = 5.0,
) -> Tuple[bytes, bytes]:
    """
    Exercise current H2C→C2H loopback wiring.

    Starts C2H read in a background thread, then writes H2C so the FPGA
    can forward data. Returns (tx, rx).
    """
    nbytes = align_down(nbytes)
    tx = make_test_payload(nbytes, pattern=pattern)
    err: List[BaseException] = []
    rx_box: List[bytes] = []

    def reader() -> None:
        try:
            rx_box.append(read_c2h(nbytes, device, channel, timeout_s=timeout_s))
        except BaseException as exc:  # noqa: BLE001 — surface to main thread
            err.append(exc)

    t = threading.Thread(target=reader, name="c2h-reader", daemon=True)
    t.start()
    # Give the C2H descriptor a moment to arm before H2C push
    time.sleep(0.05)
    try:
        write_h2c(tx, device, channel)
    except BaseException:
        t.join(timeout=timeout_s)
        raise
    t.join(timeout=timeout_s + 1.0)
    if err:
        raise err[0]
    if not rx_box:
        raise TimeoutError("C2H reader did not complete")
    return tx, rx_box[0]


class UserBar:
    """AXI-Lite user BAR (/dev/xdmaN_user) — control @0 + pattern @0x1000."""

    def __init__(self, device: int = DEFAULT_DEVICE, size: int = USER_BAR_SIZE):
        self.path = device_path("user", device)
        require_device(self.path)
        self._fd = os.open(self.path, os.O_RDWR)
        self._mm = mmap.mmap(self._fd, size, flags=mmap.MAP_SHARED)

    def close(self) -> None:
        self._mm.close()
        os.close(self._fd)

    def __enter__(self) -> "UserBar":
        return self

    def __exit__(self, *args) -> None:
        self.close()

    def read_u32(self, offset: int) -> int:
        return struct.unpack_from("<I", self._mm, offset)[0]

    def write_u32(self, offset: int, value: int) -> None:
        struct.pack_into("<I", self._mm, offset, value & 0xFFFFFFFF)

    def read_bytes(self, offset: int, nbytes: int) -> bytes:
        return bytes(self._mm[offset : offset + nbytes])

    def write_bytes(self, offset: int, data: bytes) -> None:
        self._mm[offset : offset + len(data)] = data


def print_preview(samples: Iterable, limit: int = 16) -> None:
    items = list(samples) if not hasattr(samples, "__len__") else samples
    n = len(items)
    show = min(limit, n)
    preview = ", ".join(
        f"0x{int(v) & 0xFFFFFFFFFFFFFFFF:X}" if isinstance(v, (int,)) else str(v)
        for v in items[:show]
    )
    more = f" ... (+{n - show} more)" if n > show else ""
    print(f"  samples[{n}]: [{preview}]{more}")


def load_pattern_bram(
    sequence: bytes,
    device: int = DEFAULT_DEVICE,
    offset: int = 0,
) -> None:
    """Write sequence bytes into pattern BRAM (offset within the 4 KiB window)."""
    if len(sequence) % AXIS_BYTES_PER_BEAT:
        raise ValueError("sequence length must be a multiple of 8 bytes")
    if offset + len(sequence) > PATTERN_BRAM_SIZE:
        raise ValueError(
            f"sequence ({len(sequence)} B @+{offset}) exceeds pattern BRAM "
            f"({PATTERN_BRAM_SIZE} B)"
        )
    with UserBar(device) as bar:
        bar.write_bytes(PATTERN_BRAM_BASE + offset, sequence)


def arm_mem_source(
    seq_len: int,
    repeat: int,
    device: int = DEFAULT_DEVICE,
) -> int:
    """Program SEQ_LEN/REPEAT (and LENGTH fallback) then pulse start.

    Returns total transfer size in bytes (seq_len * repeat).
    """
    seq_len = align_down(seq_len)
    if seq_len < AXIS_BYTES_PER_BEAT:
        raise ValueError("seq_len must be >= 8")
    if repeat < 1:
        raise ValueError("repeat must be >= 1")
    total = seq_len * repeat
    with UserBar(device) as bar:
        bar.write_u32(REG_LENGTH, total)
        bar.write_u32(REG_SEQ_LEN, seq_len)
        bar.write_u32(REG_REPEAT, repeat)
        bar.write_u32(REG_CTRL, 1)
    return total


def make_sequence(nbytes: int, pattern: str = "count") -> bytes:
    """Build a sequence to load into pattern BRAM."""
    return make_test_payload(nbytes, pattern=pattern)


def cmd_mem(args: argparse.Namespace) -> int:
    """Load pattern BRAM, arm SEQ_LEN/REPEAT, capture C2H.

    Order (ARM_ON_C2H=0): load BRAM → start C2H reader → arm CTRL.
    """
    seq_len = require_axis_aligned(
        args.seq_len if args.seq_len is not None else args.bytes,
        "seq_len / -n",
    )
    repeat = args.repeat
    if repeat < 1:
        raise ValueError("repeat must be >= 1")
    total = seq_len * repeat

    if args.file:
        sequence = Path(args.file).read_bytes()
        sequence = sequence[: align_down(len(sequence))]
        if not sequence:
            raise ValueError("sequence file is empty / too short")
        require_axis_aligned(len(sequence), "sequence file length")
        seq_len = len(sequence)
        total = seq_len * repeat
    else:
        sequence = make_sequence(seq_len, pattern=args.pattern)

    load_pattern_bram(sequence, args.device)

    err: List[BaseException] = []
    rx_box: List[bytes] = []

    def reader() -> None:
        try:
            rx_box.append(read_c2h(total, args.device, args.channel, timeout_s=args.timeout))
        except BaseException as exc:  # noqa: BLE001
            err.append(exc)

    t = threading.Thread(target=reader, name="c2h-reader", daemon=True)
    t.start()
    time.sleep(0.05)
    arm_mem_source(seq_len, repeat, args.device)
    t.join(timeout=args.timeout + 1.0)
    if err:
        exc = err[0]
        if isinstance(exc, (TimeoutError, EOFError)):
            print(
                f"error: {exc}\n  FPGA regs: {dump_stream_status(args.device)}",
                file=sys.stderr,
            )
            return 1
        raise exc
    if not rx_box:
        print(
            f"error: C2H reader did not complete\n"
            f"  FPGA regs: {dump_stream_status(args.device)}",
            file=sys.stderr,
        )
        return 1
    rx = rx_box[0]
    samples = parse_beats(rx, args.dtype)
    print(
        f"Mem sequence capture: {len(rx)} bytes "
        f"(seq_len={seq_len}, repeat={repeat}) from ch{args.channel}"
    )
    if args.dtype != "raw":
        print_preview(samples, args.preview)
    if args.output:
        Path(args.output).write_bytes(rx)
        print(f"Wrote raw bytes to {args.output}")
    return 0


def cmd_pattern(args: argparse.Namespace) -> int:
    """Backward-compatible alias: one-shot mem sequence of -n bytes, repeat=1."""
    args.seq_len = args.bytes
    args.repeat = 1
    args.file = None
    args.pattern = "count"
    return cmd_mem(args)


def cmd_c2h(args: argparse.Namespace) -> int:
    data = read_c2h(args.bytes, args.device, args.channel, timeout_s=args.timeout)
    samples = parse_beats(data, args.dtype)
    print(f"Read {len(data)} bytes from {device_path('c2h', args.device, args.channel)}")
    if args.dtype != "raw":
        print_preview(samples, args.preview)
    if args.output:
        Path(args.output).write_bytes(data)
        print(f"Wrote raw bytes to {args.output}")
    return 0


def cmd_loopback(args: argparse.Namespace) -> int:
    tx, rx = loopback_transfer(
        args.bytes,
        args.device,
        args.channel,
        pattern=args.pattern,
        timeout_s=args.timeout,
    )
    ok = tx == rx
    print(
        f"Loopback ch{args.channel}: {len(tx)} bytes "
        f"{'OK' if ok else 'MISMATCH'}"
    )
    if not ok:
        for i, (a, b) in enumerate(zip(tx, rx)):
            if a != b:
                print(f"  first diff at byte {i}: tx=0x{a:02x} rx=0x{b:02x}")
                break
        if len(tx) != len(rx):
            print(f"  length tx={len(tx)} rx={len(rx)}")
        return 1
    samples = parse_beats(rx, args.dtype)
    if args.dtype != "raw":
        print_preview(samples, args.preview)
    if args.output:
        Path(args.output).write_bytes(rx)
        print(f"Wrote raw bytes to {args.output}")
    return 0


def cmd_bram(args: argparse.Namespace) -> int:
    with UserBar(args.device) as bar:
        if args.write is not None:
            bar.write_u32(args.offset, args.write)
            print(f"Wrote 0x{args.write:08X} to BRAM+0x{args.offset:X}")
        value = bar.read_u32(args.offset)
        print(f"BRAM+0x{args.offset:X} = 0x{value:08X}")
    return 0

def read_bram(offset: int = 0, device: int = DEFAULT_DEVICE) -> int:
    with UserBar(device) as bar:
        value = bar.read_u32(offset)
        print(f"BRAM+0x{offset:X} = 0x{value:08X}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Read AXI-Stream samples from alinx_streamer XDMA",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  # Load a 64-beat sequence into pattern BRAM and play it 10 times
  # (sizes must be multiples of 8; ARM_ON_C2H=0 → C2H open then CTRL)
  sudo python3 read_axi_stream.py -n 512 --dtype u64 mem --repeat 10

  # Same, from a raw binary file (length must be multiple of 8)
  sudo python3 read_axi_stream.py mem --file seq.bin --repeat 4 -o capture.bin

  # One-shot (repeat=1) convenience alias
  sudo python3 read_axi_stream.py -n 4096 --dtype u64 pattern

  # Raw C2H read (needs a prior CTRL arm / separate start when ARM_ON_C2H=0)
  sudo python3 read_axi_stream.py -n 4096 --dtype u64 c2h -o capture.bin

  # Control BRAM peek/poke (@0); pattern BRAM is @0x1000
  sudo python3 read_axi_stream.py bram --offset 0x10 --write 512
  sudo python3 read_axi_stream.py bram --offset 0x1000
""",
    )
    p.add_argument("-d", "--device", type=int, default=DEFAULT_DEVICE, help="xdma device index")
    p.add_argument("-c", "--channel", type=int, default=DEFAULT_CHANNEL, choices=(0, 1))
    p.add_argument(
        "-n",
        "--bytes",
        type=parse_size,
        default=4096,
        help="transfer size (multiple of 8; suffixes K/M ok)",
    )
    p.add_argument(
        "--dtype",
        choices=("u64", "u32", "i16", "raw"),
        default="u64",
        help="how to interpret AXIS beats (default: u64)",
    )
    p.add_argument("--preview", type=int, default=16, help="samples to print")
    p.add_argument("-o", "--output", help="write raw capture to file")
    p.add_argument("--timeout", type=float, default=5.0, help="I/O timeout seconds")

    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("c2h", help="read from C2H (FPGA mem sequence source)")
    sp.set_defaults(func=cmd_c2h)

    sp = sub.add_parser(
        "mem",
        help="load pattern BRAM + arm SEQ_LEN/REPEAT + read C2H",
    )
    sp.add_argument(
        "--seq-len",
        type=parse_size,
        default=None,
        help="sequence length in bytes (default: -n/--bytes)",
    )
    sp.add_argument(
        "--repeat",
        type=int,
        default=1,
        help="how many times to play the sequence (default: 1)",
    )
    sp.add_argument(
        "--file",
        help="raw binary sequence to load (overrides generated pattern)",
    )
    sp.add_argument(
        "--pattern",
        choices=("count", "ramp16", "zeros", "ff"),
        default="count",
        help="generated sequence if --file not set",
    )
    sp.set_defaults(func=cmd_mem)

    sp = sub.add_parser("pattern", help="alias: mem with repeat=1, count pattern")
    sp.set_defaults(func=cmd_pattern)

    sp = sub.add_parser("loopback", help="H2C write + C2H read (current design)")
    sp.add_argument(
        "--pattern",
        choices=("count", "ramp16", "zeros", "ff"),
        default="count",
        help="H2C test pattern",
    )
    sp.set_defaults(func=cmd_loopback)

    sp = sub.add_parser("bram", help="read/write AXI-Lite user BAR (ctrl+pattern)")
    sp.add_argument("--offset", type=lambda s: int(s, 0), default=0)
    sp.add_argument("--write", type=lambda s: int(s, 0), default=None)
    sp.set_defaults(func=cmd_bram)

    return p


def parse_size(text: str) -> int:
    text = text.strip().lower()
    mult = 1
    if text.endswith("k"):
        mult = 1024
        text = text[:-1]
    elif text.endswith("m"):
        mult = 1024 * 1024
        text = text[:-1]
    value = int(text, 0) * mult
    if value < AXIS_BYTES_PER_BEAT or value % AXIS_BYTES_PER_BEAT:
        raise argparse.ArgumentTypeError(
            f"size must be a multiple of {AXIS_BYTES_PER_BEAT} and >= "
            f"{AXIS_BYTES_PER_BEAT} (got {value})"
        )
    return value


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    # Subcommands that don't use --bytes still inherit it; that's fine.
    try:
        return args.func(args)
    except (FileNotFoundError, TimeoutError, EOFError, OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
