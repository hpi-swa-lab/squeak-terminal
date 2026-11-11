# Keystroke-to-screen latency, measured from outside like Typometer.
#
# Focuses a window whose title matches -Title, sends a real key with SendInput and
# polls the composed screen (BitBlt from the desktop DC) until the watched region
# differs from every idle state seen before (cursor blink included). Then sends
# Backspace and waits for an idle state again.
#
#   powershell -ExecutionPolicy Bypass -File keylatency.ps1 -Title 'xterm' -Samples 30
#   -Region 'x,y,w,h'    watched rectangle in the target's own client coordinates
#   -LogicalWidth n      client width in those coordinates (DPI-unaware apps such as
#                        Squeak); 0 means the region is in physical pixels
param(
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Name = $Title,
    [int]$Samples = 30,
    [string]$Region = '',
    [int]$LogicalWidth = 0,
    [switch]$OnlyOneKey,
    [string]$DumpDir = ''
)

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

public static class KLat {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public InputUnion u; }
    [StructLayout(LayoutKind.Sequential)] struct BITMAPINFOHEADER {
        public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount;
        public uint biCompression, biSizeImage; public int biXPelsPerMeter, biYPelsPerMeter;
        public uint biClrUsed, biClrImportant; }

    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern void SwitchToThisWindow(IntPtr h, bool altTab);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] i, int size);
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint type);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr dc, ref BITMAPINFOHEADER bmi, uint usage, out IntPtr bits, IntPtr sec, uint off);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr d, int x, int y, int w, int h, IntPtr s, int sx, int sy, uint rop);

    public static IntPtr Find(string pattern) {
        IntPtr found = IntPtr.Zero;
        var re = new Regex(pattern);
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            var sb = new StringBuilder(512);
            GetWindowText(h, sb, 512);
            if (re.IsMatch(sb.ToString())) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static string TitleOf(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }

    static void Key(ushort vk, bool up) {
        var i = new INPUT[1];
        i[0].type = 1;
        i[0].u.ki.wVk = vk;
        i[0].u.ki.wScan = (ushort)MapVirtualKey(vk, 0);
        i[0].u.ki.dwFlags = up ? 2u : 0u;
        SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void Tap(ushort vk) { Key(vk, false); Key(vk, true); }

    // Gives the target real keyboard focus; SetForegroundWindow alone can leave it on nothing.
    public static void ClickRegionCenter() {
        SetCursorPos(sx + w / 2, sy + h / 2);
        Thread.Sleep(50);
        Click();
    }

    static void Click() {
        var i = new INPUT[2];
        i[0].type = 0; i[0].u.mi.dwFlags = 0x0002;
        i[1].type = 0; i[1].u.mi.dwFlags = 0x0004;
        SendInput(2, i, Marshal.SizeOf(typeof(INPUT)));
    }

    public static bool Focus(IntPtr h) {
        SetProcessDpiAwarenessContext(new IntPtr(-4));
        if (IsIconic(h)) ShowWindow(h, 9);
        bool clicked = false;
        for (int attempt = 0; attempt < 3 && GetForegroundWindow() != h; attempt++) {
            // Windows only lets the foreground thread hand over the foreground.
            uint pid;
            uint fg = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
            uint me = GetCurrentThreadId();
            AttachThreadInput(me, fg, true);
            Tap(0x12);
            BringWindowToTop(h);
            SetForegroundWindow(h);
            SwitchToThisWindow(h, true);
            AttachThreadInput(me, fg, false);
            Thread.Sleep(150);
            if (GetForegroundWindow() != h && !clicked) {
                clicked = true;
                // A click is real input, which the foreground lock always lets through.
                RECT r; GetWindowRect(h, out r);
                SetCursorPos((r.Left + r.Right) / 2, r.Top + 12);
                Click();
                Thread.Sleep(150);
            }
        }
        return GetForegroundWindow() == h;
    }

    // Region in screen pixels: rx,ry,rw,rh in client coordinates scaled by scale.
    static IntPtr screenDC, memDC, bits;
    static int sx, sy, w, h;

    public static string Setup(IntPtr win, int rx, int ry, int rw, int rh, int logicalWidth) {
        RECT c; GetClientRect(win, out c);
        var p = new POINT(); ClientToScreen(win, ref p);
        double scale = logicalWidth > 0 ? (double)c.Right / logicalWidth : 1.0;
        if (rw <= 0) { rx = 0; ry = 0; rw = (int)(c.Right / scale); rh = (int)(c.Bottom / scale); }
        sx = p.X + (int)(rx * scale); sy = p.Y + (int)(ry * scale);
        w = Math.Max(1, (int)(rw * scale)); h = Math.Max(1, (int)(rh * scale));
        SetCursorPos(sx + w / 2, sy + h / 2);
        screenDC = GetDC(IntPtr.Zero);
        memDC = CreateCompatibleDC(screenDC);
        var bmi = new BITMAPINFOHEADER();
        bmi.biSize = 40; bmi.biWidth = w; bmi.biHeight = -h; bmi.biPlanes = 1; bmi.biBitCount = 32;
        IntPtr dib = CreateDIBSection(memDC, ref bmi, 0, out bits, IntPtr.Zero, 0);
        SelectObject(memDC, dib);
        return String.Format("client {0}x{1} at {2},{3}, scale {4:F3}, watching {5}x{6} at {7},{8}",
            c.Right, c.Bottom, p.X, p.Y, scale, w, h, sx, sy);
    }

    public static string DumpDir = null;
    static int dumps = 0;
    static void Dump(string what) {
        if (DumpDir == null || dumps > 12) return;
        var bmp = new System.Drawing.Bitmap(w, h, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
        var data = bmp.LockBits(new System.Drawing.Rectangle(0, 0, w, h), System.Drawing.Imaging.ImageLockMode.WriteOnly, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
        Marshal.Copy(buffer, 0, data.Scan0, w * h);
        bmp.UnlockBits(data);
        bmp.Save(System.IO.Path.Combine(DumpDir, String.Format("{0:D2}-{1}.png", dumps++, what)));
        bmp.Dispose();
    }

    static int[] buffer;
    public static long Capture() {
        BitBlt(memDC, 0, 0, w, h, screenDC, sx, sy, 0x00CC0020);
        if (buffer == null) buffer = new int[w * h];
        Marshal.Copy(bits, buffer, 0, w * h);
        long hash = 1469598103934665603L;
        for (int i = 0; i < buffer.Length; i++) hash = (hash ^ (buffer[i] & 0xFFFFFF)) * 1099511628211L;
        return hash;
    }

    public static string Run(IntPtr win, int samples) {
        var idle = new HashSet<long>();
        var sw = Stopwatch.StartNew();
        int polls = 0;
        while (sw.ElapsedMilliseconds < 3000) { if (idle.Add(Capture())) Dump("idle"); polls++; Thread.Sleep(5); }
        var pollWatch = Stopwatch.StartNew();
        for (int i = 0; i < 50; i++) Capture();
        double pollMs = pollWatch.Elapsed.TotalMilliseconds / 50;
        var results = new List<double>();
        var rnd = new Random(1);
        int lost = 0;
        const int warmup = 5;
        for (int n = 0; n < samples + warmup; n++) {
            Thread.Sleep(150 + rnd.Next(150));
            if (GetForegroundWindow() != win && !Focus(win))
                return "ABORT before key: foreground is '" + TitleOf(GetForegroundWindow()) + "'";
            // Whatever shows 400 ms after Backspace is idle too: some terminals only
            // start blinking a while after input, so the up-front recording misses a phase.
            long now = Capture();
            if (idle.Add(now)) Dump("idle-learned");
            var t = Stopwatch.StartNew();
            Tap(0x58);
            bool seen = false;
            while (t.ElapsedMilliseconds < 2000) {
                if (!idle.Contains(Capture())) { seen = true; Dump("changed"); break; }
            }
            if (!seen) {
                // The key went somewhere else; take it back there and stop.
                Tap(0x08);
                return "ABORT: no change within 2 s, Backspace sent to undo the key";
            }
            if (n >= warmup) results.Add(t.Elapsed.TotalMilliseconds);
            if (GetForegroundWindow() != win)
                return "ABORT after key, Backspace not sent: foreground is '" + TitleOf(GetForegroundWindow()) + "'";
            Tap(0x08);
            Thread.Sleep(400);
        }
        results.Sort();
        if (results.Count == 0) return "no samples, lost " + lost;
        Func<double, double> q = f => results[Math.Min(results.Count - 1, (int)(f * results.Count))];
        return String.Format(System.Globalization.CultureInfo.InvariantCulture,
            "n={0} lost={1} idleStates={2} poll={3:F2}ms min={4:F1} p10={5:F1} median={6:F1} p90={7:F1} max={8:F1} all=[{9}]",
            results.Count, lost, idle.Count, pollMs, results[0], q(0.1), q(0.5), q(0.9), results[results.Count - 1],
            String.Join(",", results.ConvertAll(x => x.ToString("F1", System.Globalization.CultureInfo.InvariantCulture))));
    }
}
'@

$win = [KLat]::Find($Title)
if ($win -eq [IntPtr]::Zero) { Write-Output "$Name : no window matches '$Title'"; exit 1 }
if (-not [KLat]::Focus($win)) { Write-Output "$Name : could not focus '$([KLat]::TitleOf($win))'"; exit 1 }
Start-Sleep -Milliseconds 500
if ($OnlyOneKey) { Start-Sleep -Milliseconds 1000; [KLat]::Tap(0x58); Write-Output "$Name : sent one key"; exit 0 }
$r = @(0, 0, 0, 0)
if ($Region -ne '') { $r = $Region.Split(',') | ForEach-Object { [int]$_ } }
if ($DumpDir -ne '') { New-Item -ItemType Directory -Force $DumpDir | Out-Null; [KLat]::DumpDir = $DumpDir }
$setup = [KLat]::Setup($win, $r[0], $r[1], $r[2], $r[3], $LogicalWidth)
[KLat]::ClickRegionCenter()
Start-Sleep -Milliseconds 600
$result = [KLat]::Run($win, $Samples)
Write-Output "$Name : $([KLat]::TitleOf($win)) | $setup"
Write-Output "$Name : $result"
