using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using ScottPlot;
using XdmaPlotter.Xdma;

namespace XdmaPlotter;

public partial class MainWindow : Window
{
    private const int MaxPlotPoints = 8192;
    private bool _busy;

    public MainWindow()
    {
        InitializeComponent();
        AvaPlot1.Plot.Title("XDMA C2H capture");
        AvaPlot1.Plot.XLabel("sample");
        AvaPlot1.Plot.YLabel("value");
        AvaPlot1.Refresh();
    }

    private async void OnCaptureClick(object? sender, RoutedEventArgs e)
    {
        if (_busy) return;
        _busy = true;
        CaptureButton.IsEnabled = false;
        SetStatus("Capturing…");

        int device = (int)(DeviceBox.Value ?? 0);
        int channel = (int)(ChannelBox.Value ?? 0);

        try
        {
            int nbytes = ParseBytes(BytesBox.Text);
            int repeat = (int)(RepeatBox.Value ?? 1);
            if (repeat < 1)
                throw new ArgumentOutOfRangeException(nameof(repeat), "repeat must be >= 1");

            string dtype = GetSelectedDtype();
            bool armMem = ArmPatternBox.IsChecked == true;
            var timeout = TimeSpan.FromSeconds(10);

            // Matches Python: mem = count sequence + repeat; raw c2h = ReadC2h only.
            byte[] raw = armMem
                ? await XdmaStream.CaptureMemSequenceAsync(
                    XdmaStream.MakeCountSequence(nbytes),
                    device, channel, repeat, timeout)
                : await XdmaStream.ReadC2hAsync(nbytes * repeat, device, channel, timeout);

            double[] samples = XdmaStream.ParseBeatsAsDoubles(raw, dtype);
            double[] plotted = Downsample(samples, MaxPlotPoints);

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                PlotSamples(plotted);
                SetStatus(
                    $"OK — {raw.Length} bytes, {samples.Length} samples" +
                    (armMem ? $" (seq={nbytes}, repeat={repeat})" : string.Empty) +
                    (plotted.Length < samples.Length
                        ? $" (showing {plotted.Length} downsampled)"
                        : string.Empty) +
                    $" from {XdmaPaths.C2h(device, channel)}");
            });
        }
        catch (Exception ex)
        {
            string detail = ex.Message;
            if (!detail.Contains("FPGA regs", StringComparison.Ordinal))
            {
                try
                {
                    detail += $"; FPGA regs: {XdmaStream.DumpStreamStatus(device)}";
                }
                catch
                {
                    // ignore status peek failures
                }
            }

            SetStatus($"Error: {detail}");
        }
        finally
        {
            _busy = false;
            CaptureButton.IsEnabled = true;
        }
    }

    private void OnClearClick(object? sender, RoutedEventArgs e)
    {
        AvaPlot1.Plot.Clear();
        AvaPlot1.Refresh();
        SetStatus("Cleared");
    }

    private void PlotSamples(double[] ys)
    {
        AvaPlot1.Plot.Clear();
        var sig = AvaPlot1.Plot.Add.Signal(ys);
        sig.LegendText = "C2H";
        AvaPlot1.Plot.Axes.AutoScale();
        AvaPlot1.Refresh();
    }

    private void SetStatus(string text) => StatusText.Text = text;

    private string GetSelectedDtype()
    {
        if (DtypeBox.SelectedItem is ComboBoxItem { Content: string s })
            return s;
        return "u64";
    }

    private static int ParseBytes(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return 512;

        text = text.Trim().ToLowerInvariant();
        int mult = 1;
        if (text.EndsWith('k'))
        {
            mult = 1024;
            text = text[..^1];
        }
        else if (text.EndsWith('m'))
        {
            mult = 1024 * 1024;
            text = text[..^1];
        }

        if (!int.TryParse(text, out int value))
            throw new FormatException("Bytes must be an integer (suffixes K/M ok)");

        return XdmaPaths.RequireAxisAligned(value * mult, "Bytes");
    }

    /// <summary>Keep first/last and evenly spaced mid points for plotting.</summary>
    private static double[] Downsample(double[] samples, int maxPoints)
    {
        if (samples.Length <= maxPoints)
            return samples;

        var result = new double[maxPoints];
        for (int i = 0; i < maxPoints; i++)
        {
            int src = (int)((long)i * (samples.Length - 1) / (maxPoints - 1));
            result[i] = samples[src];
        }

        return result;
    }
}
