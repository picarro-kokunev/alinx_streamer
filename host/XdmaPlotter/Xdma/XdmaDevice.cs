using System.Buffers.Binary;
using System.IO.MemoryMappedFiles;
using System.Runtime.InteropServices;

namespace XdmaPlotter.Xdma;

/// <summary>
/// Host-side access to Xilinx XDMA char devices used by alinx_streamer.
/// Mirrors host/read_axi_stream.py device paths and BRAM register map.
/// </summary>
public static class XdmaPaths
{
    public const int AxisBytesPerBeat = 8;
    public const int BramSize = 4096;

    public const int RegCtrl = 0x00;
    public const int RegLength = 0x04;
    public const int RegStatus = 0x08;
    public const int RegBeatCnt = 0x0C;
    public const int RegSeedLo = 0x10;
    public const int RegSeedHi = 0x14;

    public static string C2h(int device, int channel) => $"/dev/xdma{device}_c2h_{channel}";
    public static string H2c(int device, int channel) => $"/dev/xdma{device}_h2c_{channel}";
    public static string User(int device) => $"/dev/xdma{device}_user";

    public static int AlignDown(int nbytes, int align = AxisBytesPerBeat) =>
        nbytes - (nbytes % align);
}

public sealed class UserBar : IDisposable
{
    private readonly MemoryMappedFile _mmf;
    private readonly MemoryMappedViewAccessor _view;
    private bool _disposed;

    public UserBar(int device, int size = XdmaPaths.BramSize)
    {
        string path = XdmaPaths.User(device);
        if (!File.Exists(path))
            throw new FileNotFoundException($"User BAR not found: {path}", path);

        var fs = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite);
        _mmf = MemoryMappedFile.CreateFromFile(
            fs, mapName: null, size, MemoryMappedFileAccess.ReadWrite,
            HandleInheritability.None, leaveOpen: false);
        _view = _mmf.CreateViewAccessor(0, size, MemoryMappedFileAccess.ReadWrite);
    }

    public uint ReadU32(int offset) => _view.ReadUInt32(offset);

    public void WriteU32(int offset, uint value) => _view.Write(offset, value);

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _view.Dispose();
        _mmf.Dispose();
    }
}

public static class XdmaStream
{
    public static async Task<byte[]> ReadC2hAsync(
        int nbytes,
        int device,
        int channel,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        nbytes = XdmaPaths.AlignDown(nbytes);
        if (nbytes < XdmaPaths.AxisBytesPerBeat)
            throw new ArgumentOutOfRangeException(nameof(nbytes), "size must be >= 8 and multiple of 8");

        string path = XdmaPaths.C2h(device, channel);
        if (!File.Exists(path))
            throw new FileNotFoundException($"C2H device not found: {path}", path);

        await using var fs = new FileStream(
            path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite,
            bufferSize: 1 << 20, useAsync: true);

        var buffer = new byte[nbytes];
        int offset = 0;
        CancellationToken ct = cancellationToken;
        CancellationTokenSource? linked = null;
        if (timeout is { } t)
        {
            linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            linked.CancelAfter(t);
            ct = linked.Token;
        }

        try
        {
            while (offset < nbytes)
            {
                ct.ThrowIfCancellationRequested();
                int n = await fs.ReadAsync(buffer.AsMemory(offset, nbytes - offset), ct)
                    .ConfigureAwait(false);
                if (n == 0)
                    throw new EndOfStreamException($"short read: got {offset}/{nbytes} bytes (EOF)");
                offset += n;
            }
        }
        finally
        {
            linked?.Dispose();
        }

        return buffer;
    }

    /// <summary>Program BRAM stream regs and pulse start (pattern source).</summary>
    public static void ArmPatternSource(int nbytes, int device, ulong seed = 0)
    {
        nbytes = XdmaPaths.AlignDown(nbytes);
        using var bar = new UserBar(device);
        bar.WriteU32(XdmaPaths.RegLength, (uint)nbytes);
        bar.WriteU32(XdmaPaths.RegSeedLo, (uint)(seed & 0xFFFF_FFFFUL));
        bar.WriteU32(XdmaPaths.RegSeedHi, (uint)(seed >> 32));
        bar.WriteU32(XdmaPaths.RegCtrl, 1);
    }

    /// <summary>
    /// Arm C2H read first (so XDMA asserts tready), then pulse FPGA start via BRAM.
    /// </summary>
    public static async Task<byte[]> CapturePatternAsync(
        int nbytes,
        int device,
        int channel,
        ulong seed = 0,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        nbytes = XdmaPaths.AlignDown(nbytes);
        var readTask = ReadC2hAsync(nbytes, device, channel, timeout, cancellationToken);
        await Task.Delay(50, cancellationToken).ConfigureAwait(false);
        ArmPatternSource(nbytes, device, seed);
        return await readTask.ConfigureAwait(false);
    }

    public static double[] ParseBeatsAsDoubles(ReadOnlySpan<byte> data, string dtype)
    {
        if (data.Length % XdmaPaths.AxisBytesPerBeat != 0)
            throw new ArgumentException(
                $"buffer length {data.Length} is not a multiple of {XdmaPaths.AxisBytesPerBeat}-byte AXIS beat");

        return dtype switch
        {
            "u64" => ParseU64(data),
            "u32" => ParseU32(data),
            "i16" => ParseI16(data),
            _ => throw new ArgumentException($"unsupported dtype '{dtype}'; use u64, u32, or i16"),
        };
    }

    private static double[] ParseU64(ReadOnlySpan<byte> data)
    {
        int count = data.Length / 8;
        var samples = new double[count];
        var ulongs = MemoryMarshal.Cast<byte, ulong>(data);
        for (int i = 0; i < count; i++)
            samples[i] = ulongs[i];
        return samples;
    }

    private static double[] ParseU32(ReadOnlySpan<byte> data)
    {
        int count = data.Length / 4;
        var samples = new double[count];
        for (int i = 0; i < count; i++)
            samples[i] = BinaryPrimitives.ReadUInt32LittleEndian(data.Slice(i * 4, 4));
        return samples;
    }

    private static double[] ParseI16(ReadOnlySpan<byte> data)
    {
        int count = data.Length / 2;
        var samples = new double[count];
        for (int i = 0; i < count; i++)
            samples[i] = BinaryPrimitives.ReadInt16LittleEndian(data.Slice(i * 2, 2));
        return samples;
    }
}
