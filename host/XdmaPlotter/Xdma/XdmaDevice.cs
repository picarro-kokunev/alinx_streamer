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
    public const int CtrlBramSize = 4096;
    public const int PatternBramBase = 0x1000;
    public const int PatternBramSize = 4096;
    public const int UserBarSize = PatternBramBase + PatternBramSize;

    /// <summary>Legacy alias for control BRAM size.</summary>
    public const int BramSize = CtrlBramSize;

    public const int RegCtrl = 0x00;
    public const int RegLength = 0x04;
    public const int RegStatus = 0x08;
    public const int RegBeatCnt = 0x0C;
    public const int RegSeqLen = 0x10;
    public const int RegRepeat = 0x14;

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

    public UserBar(int device, int size = XdmaPaths.UserBarSize)
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

    public void WriteBytes(int offset, ReadOnlySpan<byte> data)
    {
        // MemoryMappedViewAccessor has no Span overload; copy once into a buffer.
        byte[] buf = data.ToArray();
        _view.WriteArray(offset, buf, 0, buf.Length);
    }

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

    /// <summary>Load sequence into pattern BRAM at 0x1000.</summary>
    public static void LoadPatternBram(ReadOnlySpan<byte> sequence, int device, int offset = 0)
    {
        if (sequence.Length % XdmaPaths.AxisBytesPerBeat != 0)
            throw new ArgumentException("sequence length must be a multiple of 8 bytes");
        if (offset + sequence.Length > XdmaPaths.PatternBramSize)
            throw new ArgumentException("sequence exceeds pattern BRAM size");

        using var bar = new UserBar(device);
        bar.WriteBytes(XdmaPaths.PatternBramBase + offset, sequence);
    }

    /// <summary>Program SEQ_LEN/REPEAT and pulse start (memory sequence source).</summary>
    public static int ArmMemSource(int seqLen, int repeat, int device)
    {
        seqLen = XdmaPaths.AlignDown(seqLen);
        if (seqLen < XdmaPaths.AxisBytesPerBeat)
            throw new ArgumentOutOfRangeException(nameof(seqLen));
        if (repeat < 1)
            throw new ArgumentOutOfRangeException(nameof(repeat));

        int total = seqLen * repeat;
        using var bar = new UserBar(device);
        bar.WriteU32(XdmaPaths.RegLength, (uint)total);
        bar.WriteU32(XdmaPaths.RegSeqLen, (uint)seqLen);
        bar.WriteU32(XdmaPaths.RegRepeat, (uint)repeat);
        bar.WriteU32(XdmaPaths.RegCtrl, 1);
        return total;
    }

    /// <summary>Build ascending uint64 LE beats (same as Python pattern=count).</summary>
    public static byte[] MakeCountSequence(int nbytes)
    {
        nbytes = XdmaPaths.AlignDown(nbytes);
        if (nbytes < XdmaPaths.AxisBytesPerBeat)
            throw new ArgumentOutOfRangeException(nameof(nbytes), "size must be >= 8");

        int beats = nbytes / 8;
        var buf = new byte[nbytes];
        for (int i = 0; i < beats; i++)
            BinaryPrimitives.WriteUInt64LittleEndian(buf.AsSpan(i * 8, 8), (ulong)i);
        return buf;
    }

    /// <summary>Legacy: arm a one-shot transfer of nbytes (repeat=1).</summary>
    public static void ArmPatternSource(int nbytes, int device, ulong seed = 0)
    {
        _ = seed; // seed replaced by SEQ_LEN/REPEAT in mem streamer
        ArmMemSource(nbytes, repeat: 1, device);
    }

    /// <summary>
    /// Load a count sequence of <paramref name="nbytes"/>, arm (repeat=1), capture C2H.
    /// Matches Python <c>pattern</c> / one-shot <c>mem</c>.
    /// </summary>
    public static Task<byte[]> CapturePatternAsync(
        int nbytes,
        int device,
        int channel,
        ulong seed = 0,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        _ = seed;
        byte[] sequence = MakeCountSequence(nbytes);
        return CaptureMemSequenceAsync(
            sequence, device, channel, repeat: 1, timeout, cancellationToken);
    }

    /// <summary>
    /// Load sequence into pattern BRAM, play it <paramref name="repeat"/> times, capture C2H.
    /// Parameter order matches sibling capture APIs: payload, device, channel, then options.
    /// </summary>
    public static async Task<byte[]> CaptureMemSequenceAsync(
        byte[] sequence,
        int device,
        int channel,
        int repeat = 1,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(sequence);
        if (repeat < 1)
            throw new ArgumentOutOfRangeException(nameof(repeat), "repeat must be >= 1");

        int seqLen = XdmaPaths.AlignDown(sequence.Length);
        if (seqLen < XdmaPaths.AxisBytesPerBeat)
            throw new ArgumentException("sequence too short (need multiple of 8, >= 8)", nameof(sequence));

        LoadPatternBram(sequence.AsSpan(0, seqLen), device);
        int total = checked(seqLen * repeat);
        var readTask = ReadC2hAsync(total, device, channel, timeout, cancellationToken);
        await Task.Delay(50, cancellationToken).ConfigureAwait(false);
        ArmMemSource(seqLen, repeat, device);
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
