#!/usr/bin/env python3
"""
Read samples from the alinx_streamer XDMA AXI-Stream path.

Hardware (design_1):
  Host PCIe ──► xdma_0 (AXI Stream mode, Gen2 x2, 64-bit @ 125 MHz)
                  │
                  ├─ M_AXIS_H2C_0 ──► S_AXIS_C2H_0   (loopback)
                  ├─ samples_generator_0 ──► S_AXIS_C2H_1
                  └─ M_AXI_LITE   ──► BRAM (4 KiB @ 0x0)
                        ▲
                        └── samples_generator reads port B

BRAM map:
  0x00  CTRL       bit0 = run (1=start, 0=stop)
  0x04  N_SAMPLES  number of int16 samples
  0x10  samples    int16 LE, two samples per 32-bit word

Device nodes (Xilinx dma_ip_drivers xdma):
  /dev/xdma0_h2c_{0,1}   host → card (AXIS)
  /dev/xdma0_c2h_{0,1}   card → host (AXIS)
  /dev/xdma0_user        AXI-Lite BAR (BRAM)
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
DEFAULT_DEVICE = 0
DEFAULT_CHANNEL = 0
STREAM_CHANNEL = 1  # samples_generator drives C2H_1

# BRAM register map (byte offsets)
REG_CTRL = 0x00
REG_N_SAMPLES = 0x04
REG_STATUS = 0x08
SAMPLE_BASE = 0x10
MAX_SAMPLES = (BRAM_SIZE - SAMPLE_BASE) // 2


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

    def write_bytes(self, offset: int, data: bytes) -> None:
        self._mm[offset : offset + len(data)] = data


def pack_i16_samples(samples: Sequence[int]) -> bytes:
    """Pack int16 values into BRAM words (two samples per 32-bit LE word)."""
    if not samples:
        raise ValueError("samples must not be empty")
    if len(samples) > MAX_SAMPLES:
        raise ValueError(f"at most {MAX_SAMPLES} samples fit in BRAM")
    out = bytearray()
    idx = 0
    while idx < len(samples):
        lo = samples[idx] & 0xFFFF
        hi = (samples[idx + 1] & 0xFFFF) if idx + 1 < len(samples) else 0
        out.extend(struct.pack("<HH", lo, hi))
        idx += 2
    return bytes(out)


def make_i16_pattern(count: int, pattern: str = "ramp16") -> List[int]:
    if count <= 0:
        raise ValueError("count must be > 0")
    if count > MAX_SAMPLES:
        raise ValueError(f"at most {MAX_SAMPLES} samples fit in BRAM")
    if pattern == "ramp16":
        return [i & 0xFFFF for i in range(count)]
    if pattern == "zeros":
        return [0] * count
    if pattern == "ff":
        return [0xFFFF] * count
    if pattern == "sine":
        import math

        return [int(32767 * math.sin(2 * math.pi * i / count)) & 0xFFFF for i in range(count)]
    raise ValueError(f"unknown pattern {pattern!r}")


def load_samples(
    samples: Sequence[int],
    device: int = DEFAULT_DEVICE,
) -> int:
    """Load N int16 samples into BRAM and set N_SAMPLES register."""
    packed = pack_i16_samples(samples)
    with UserBar(device) as bar:
        bar.write_u32(REG_N_SAMPLES, len(samples))
        bar.write_bytes(SAMPLE_BASE, packed)
    return len(samples)


def load_samples_from_file(path: Path, device: int = DEFAULT_DEVICE) -> int:
    raw = path.read_bytes()
    if len(raw) % 2:
        raise ValueError("sample file length must be a multiple of 2 bytes (int16)")
    count = len(raw) // 2
    samples = list(struct.unpack(f"<{count}h", raw))
    return load_samples(samples, device=device)


def start_stream(device: int = DEFAULT_DEVICE) -> None:
    with UserBar(device) as bar:
        bar.write_u32(REG_CTRL, 1)


def stop_stream(device: int = DEFAULT_DEVICE) -> None:
    with UserBar(device) as bar:
        bar.write_u32(REG_CTRL, 0)


def stream_status(device: int = DEFAULT_DEVICE) -> int:
    with UserBar(device) as bar:
        return bar.read_u32(REG_CTRL) & 1


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


def cmd_load_samples(args: argparse.Namespace) -> int:
    if args.file:
        count = load_samples_from_file(Path(args.file), args.device)
        print(f"Loaded {count} int16 samples from {args.file} into BRAM+0x{SAMPLE_BASE:X}")
    else:
        samples = make_i16_pattern(args.samples, args.pattern)
        count = load_samples(samples, args.device)
        print(f"Loaded {count} generated int16 samples ({args.pattern}) into BRAM+0x{SAMPLE_BASE:X}")
    return 0


def cmd_start_stream(args: argparse.Namespace) -> int:
    start_stream(args.device)
    print(f"Streaming started (REG_CTRL @ BRAM+0x{REG_CTRL:X} = 1)")
    return 0


def cmd_stop_stream(args: argparse.Namespace) -> int:
    stop_stream(args.device)
    print(f"Streaming stopped (REG_CTRL @ BRAM+0x{REG_CTRL:X} = 0)")
    return 0


def cmd_stream_capture(args: argparse.Namespace) -> int:
    """Load samples, start generator, read C2H_1, then stop."""
    if args.file:
        load_samples_from_file(Path(args.file), args.device)
    else:
        load_samples(make_i16_pattern(args.samples, args.pattern), args.device)

    err: List[BaseException] = []
    rx_box: List[bytes] = []

    def reader() -> None:
        try:
            rx_box.append(
                read_c2h(args.bytes, args.device, STREAM_CHANNEL, timeout_s=args.timeout)
            )
        except BaseException as exc:  # noqa: BLE001
            err.append(exc)

    t = threading.Thread(target=reader, name="c2h1-reader", daemon=True)
    t.start()
    time.sleep(0.05)
    start_stream(args.device)
    try:
        t.join(timeout=args.timeout + 1.0)
    finally:
        stop_stream(args.device)

    if err:
        raise err[0]
    if not rx_box:
        raise TimeoutError("C2H_1 reader did not complete")

    data = rx_box[0]
    print(f"Read {len(data)} bytes from {device_path('c2h', args.device, STREAM_CHANNEL)}")
    samples = parse_beats(data, args.dtype)
    if args.dtype != "raw":
        print_preview(samples, args.preview)
    if args.output:
        Path(args.output).write_bytes(data)
        print(f"Wrote raw bytes to {args.output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Read AXI-Stream samples from alinx_streamer XDMA",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  # Channel 0 loopback smoke test (unchanged)
  sudo python3 read_axi_stream.py loopback -n 4096

  # Load 1024 ramp samples, start generator, capture from C2H_1
  sudo python3 read_axi_stream.py load-samples -S 1024 --pattern ramp16
  sudo python3 read_axi_stream.py start-stream
  sudo python3 read_axi_stream.py c2h -c 1 -n 8192 --dtype i16

  # One-shot: load + stream + capture
  sudo python3 read_axi_stream.py stream-capture -S 256 --pattern ramp16 -n 4096 --dtype i16

  # Stop streaming
  sudo python3 read_axi_stream.py stop-stream

  # BRAM peek/poke
  sudo python3 read_axi_stream.py bram --offset 0 --write 0xA5A5A5A5
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

    sp = sub.add_parser("c2h", help="read from C2H (needs FPGA AXIS source)")
    sp.set_defaults(func=cmd_c2h)

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

    sp = sub.add_parser("load-samples", help="load int16 samples into BRAM buffer")
    sp.add_argument(
        "-S",
        "--samples",
        type=int,
        default=256,
        help=f"number of int16 samples to generate (max {MAX_SAMPLES})",
    )
    sp.add_argument(
        "--pattern",
        choices=("ramp16", "zeros", "ff", "sine"),
        default="ramp16",
        help="generated sample pattern (ignored with --file)",
    )
    sp.add_argument("--file", help="raw int16 LE file to load")
    sp.set_defaults(func=cmd_load_samples)

    sp = sub.add_parser("start-stream", help="start samples_generator on C2H_1")
    sp.set_defaults(func=cmd_start_stream)

    sp = sub.add_parser("stop-stream", help="stop samples_generator")
    sp.set_defaults(func=cmd_stop_stream)

    sp = sub.add_parser(
        "stream-capture",
        help="load samples, start generator, read C2H_1, stop",
    )
    sp.add_argument(
        "-S",
        "--samples",
        type=int,
        default=256,
        help="generate this many samples before capture",
    )
    sp.add_argument(
        "--pattern",
        choices=("ramp16", "zeros", "ff", "sine"),
        default="ramp16",
    )
    sp.add_argument("--file", help="raw int16 LE file to load before capture")
    sp.set_defaults(func=cmd_stream_capture)

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
