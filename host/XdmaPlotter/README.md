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

- **Capture** — with **Arm pattern** checked: load count sequence into pattern BRAM @ `0x1000`, arm `SEQ_LEN`/`REPEAT`, then C2H read (Python `pattern` / `mem`). Unchecked: raw C2H only.
- **Bytes** — transfer / sequence size, multiple of 8 (supports `K`/`M` suffixes)
- **Dtype** — `u64` / `u32` / `i16` beat interpretation

## API note

`CaptureMemSequenceAsync(sequence, device, channel, repeat = 1, …)` — uses `byte[]` (not `Span`) because async methods cannot take `ReadOnlySpan<T>`.
