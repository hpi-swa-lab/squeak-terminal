# Closes the windows opened by start-targets.ps1 by posting WM_CLOSE to each window.
# Not taskkill: Windows Terminal runs all its windows in one process.
param([string]$Title = '^KLAT-')

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Text.RegularExpressions; using System.Collections.Generic;
public static class Closer {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static List<string> Close(string pattern) {
        var closed = new List<string>(); var re = new Regex(pattern);
        EnumWindows((h, l) => {
            var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
            if (IsWindowVisible(h) && re.IsMatch(sb.ToString())) { PostMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); closed.Add(sb.ToString()); }
            return true; }, IntPtr.Zero);
        return closed;
    }
}
'@
[Closer]::Close($Title) | ForEach-Object { "closed: $_" }
