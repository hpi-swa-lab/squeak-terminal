# Keystroke-to-screen latency

Measures from outside, like Typometer: `keylatency.ps1` sends a real key with `SendInput`
and polls the composed desktop (`BitBlt` from the screen DC) until the watched region
changes, then sends Backspace. Works for any Windows window, including Squeak and WSLg
windows.

```powershell
# Copy the scripts to a Windows path first; PowerShell will not run them from \\wsl$.
.\start-targets.ps1 -Targets conhost,wt        # cmd.exe with prompt "> ", titled KLAT-*
.\keylatency.ps1 -Title '^KLAT-WT$' -Name wt -Samples 40 -Region '0,92,900,44'
.\keylatency.ps1 -Title '^Squeak!' -Name swaterm -Samples 40 -Region '1507,462,600,36' -LogicalWidth 2505
.\close-targets.ps1                            # WM_CLOSE, not taskkill (one WT process)
```

- `-Region x,y,w,h` is in the target's client coordinates. Pick the prompt row: the harness
  clicks the region's centre to give the target real keyboard focus, so the centre must lie
  on the target's content. `-LogicalWidth` scales Squeak coordinates (its `Display width`).
- `-DumpDir` saves the frames it compares as PNG. Look at them before trusting a run.
- Idle states (cursor blink phases) are recorded for 3 s and then learned: whatever shows
  400 ms after Backspace counts as idle. The first 5 samples are warm-up.
- The screen capture waits for the next composed frame (~16.5 ms per poll at 60 Hz), so
  results come in display frames: 17, 33, 50 ms. That is what reaches the eye, minus
  the monitor's own scan-out.
- Before each key the harness checks that the target is the foreground window. If a key
  causes no change within 2 s, it sends one Backspace to take it back and stops.
- Nobody may touch keyboard or mouse during a run.

In Squeak, the hand's focus comes back to the previous morph when the VM regains the
OS focus (`PasteUpMorph>>windowEvent:`, `WindowHostFocusMorph`). Setting the focus over
MCP while Squeak is in the background is therefore unreliable; the click is what works.
