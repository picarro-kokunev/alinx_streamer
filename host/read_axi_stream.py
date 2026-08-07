#!/usr/bin/env python3
"""
Read samples from the alinx_streamer XDMA AXI-Stream path.

Hardware (design_1):
  Host PCIe ──► xdma_0 (AXI Stream mode, Gen2 x2, 64-bit @ 125 MHz)
                  │
                  ├─ c2h_streamer_0 ──► S_AXIS_C2H_0  (pattern source)
                  ├─ h2c_axis_sink_* ◄── M_AXIS_H2C_* (discard)
                  └─ M_AXI_LITE   ──► BRAM (4 KiB @ 0x0, port A host / port B FPGA)

BRAM register map (stream control via port B):
  0x00 CTRL [0]=start   0x04 LENGTH   0x08 STATUS   0x0C BEAT_CNT
  0x10 SEED_LO          0x14 SEED_HI

Device nodes (Xilinx dma_ip_drivers xdma):
  /dev/xdma0_h2c_{0,1}   host → card (AXIS)
  /dev/xdma0_c2h_{0,1}   card → host (AXIS)
  /dev/xdma0_user        AXI-Lite BAR (BRAM)

Current bitstream drives S_AXIS_C2H_0 from c2h_pattern_source (ascending
64-bit counter).  ARM_ON_C2H is enabled: opening a C2H read also arms the
source when LENGTH is set in BRAM (default 4096).  Use the pattern subcommand
or write BRAM regs manually, then read C2H.
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
BRAM_SIZE = 4096
# Stream control register offsets (see stream_ctrl_regs.v)
REG_CTRL     = 0x00
REG_LENGTH   = 0x04
REG_STATUS   = 0x08
REG_BEAT_CNT = 0x0C
REG_SEED_LO  = 0x10
REG_SEED_HI  = 0x14
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
    """AXI-Lite user BAR (/dev/xdmaN_user) — 4 KiB BRAM at offset 0."""

    def __init__(self, device: int = DEFAULT_DEVICE, size: int = BRAM_SIZE):
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


def arm_pattern_source(
    nbytes: int,
    device: int = DEFAULT_DEVICE,
    seed: int = 0,
) -> None:
    """Program BRAM control regs and pulse start."""
    nbytes = align_down(nbytes)
    with UserBar(device) as bar:
        bar.write_u32(REG_LENGTH, nbytes)
        bar.write_u32(REG_SEED_LO, seed & 0xFFFFFFFF)
        bar.write_u32(REG_SEED_HI, (seed >> 32) & 0xFFFFFFFF)
        bar.write_u32(REG_CTRL, 1)


def cmd_pattern(args: argparse.Namespace) -> int:
    nbytes = align_down(args.bytes)
    # Arm C2H read first so XDMA asserts tready, then pulse FPGA start.
    err: List[BaseException] = []
    rx_box: List[bytes] = []

    def reader() -> None:
        try:
            rx_box.append(read_c2h(nbytes, args.device, args.channel, timeout_s=args.timeout))
        except BaseException as exc:  # noqa: BLE001
            err.append(exc)

    t = threading.Thread(target=reader, name="c2h-reader", daemon=True)
    t.start()
    time.sleep(0.05)
    arm_pattern_source(nbytes, args.device, seed=args.seed)
    t.join(timeout=args.timeout + 1.0)
    if err:
        raise err[0]
    if not rx_box:
        raise TimeoutError("C2H reader did not complete")
    rx = rx_box[0]
    samples = parse_beats(rx, args.dtype)
    print(f"Pattern capture: {len(rx)} bytes from ch{args.channel}")
    if args.dtype != "raw":
        print_preview(samples, args.preview)
    if args.output:
        Path(args.output).write_bytes(rx)
        print(f"Wrote raw bytes to {args.output}")
    return 0


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


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Read AXI-Stream samples from alinx_streamer XDMA",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  # Current bitstream: H2C↔C2H loopback smoke test
  sudo python3 read_axi_stream.py loopback -n 4096

  # FPGA pattern source on S_AXIS_C2H_0 (BRAM-armed or ARM_ON_C2H default length)
  sudo python3 read_axi_stream.py pattern -n 4096 --dtype u64

  # Raw C2H read (arms transfer; pattern may auto-start if ARM_ON_C2H=1)
  sudo python3 read_axi_stream.py c2h -n 1M --dtype u64 -o capture.bin

  # AXI-Lite BRAM peek/poke (4 KiB @ BAR user offset 0)
  sudo python3 read_axi_stream.py bram --offset 0 --write 0xA5A5A5A5
  sudo python3 read_axi_stream.py bram --offset 0
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

    sp = sub.add_parser("c2h", help="read from C2H (FPGA pattern source)")
    sp.set_defaults(func=cmd_c2h)

    sp = sub.add_parser("pattern", help="arm BRAM regs + read C2H pattern")
    sp.add_argument("--seed", type=lambda s: int(s, 0), default=0, help="64-bit seed")
    sp.set_defaults(func=cmd_pattern)

    sp = sub.add_parser("loopback", help="H2C write + C2H read (current design)")
    sp.add_argument(
        "--pattern",
        choices=("count", "ramp16", "zeros", "ff"),
        default="count",
        help="H2C test pattern",
    )
    sp.set_defaults(func=cmd_loopback)

    sp = sub.add_parser("bram", help="read/write 4 KiB AXI-Lite BRAM")
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
    if value < AXIS_BYTES_PER_BEAT:
        raise argparse.ArgumentTypeError("size must be >= 8")
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
