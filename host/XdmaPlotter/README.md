# XdmaPlotter

Simple Avalonia UI for Linux: capture XDMA C2H stream samples and plot them.

## Run

```bash
export PATH="$HOME/.dotnet:$PATH"   # if needed
cd host/XdmaPlotter
dotnet run -c Release
```

Needs access to `/dev/xdma*` (same as `host/read_axi_stream.py`).

## UI

- **Capture** — read C2H (`/dev/xdmaN_c2h_M`); with **Arm pattern** checked, starts the reader then pulses BRAM CTRL (same order as Python `pattern`)
- **Bytes** — transfer size, multiple of 8 (supports `K`/`M` suffixes)
- **Dtype** — `u64` / `u32` / `i16` beat interpretation
