# XdmaPlotter

Simple Avalonia UI for Linux: capture XDMA C2H stream samples and plot them.

Matches `host/read_axi_stream.py` mem/pattern flow with **ARM_ON_C2H=0**:
load pattern BRAM → open C2H → pulse CTRL (`SEQ_LEN`/`REPEAT`).

## Run

```bash
export PATH="$HOME/.dotnet:$PATH"   # if needed
cd host/XdmaPlotter
dotnet run -c Release
```

Needs access to `/dev/xdma*` and a bitstream rebuilt with `ARM_ON_C2H=0`.

## UI

- **Capture** + **Arm mem** — count sequence into pattern BRAM @ `0x1000`, then C2H, then CTRL (Python `mem`)
- **Bytes** — sequence length (multiple of 8; `K`/`M` ok)
- **Repeat** — play count (`--repeat`)
- **Dtype** — `u64` / `u32` / `i16`
- On timeout/error, status line includes FPGA `STATUS` / `BEAT_CNT` when possible

Equivalent CLI:

```bash
sudo python3 host/read_axi_stream.py -n 512 --dtype u64 mem --repeat 10
```
