# Squeak Terminal

Squeak Terminal is a interactive **VT100 / VT102 / xterm** terminal emulator
for [Squeak](https://squeak.org). It can run a shell bash and modern terminal programs like opencode in a Morphic window.

It it implemented with [**libvterm**](https://github.com/neovim/libvterm) via **FFI**. 
It does the heavy lifting and parses the escape sequences and maintains the screen
grid. Squeak feeds it bytes from a pseudo-terminal and reads back the cell grid to
draw it; the shell is spawned with libc's `forkpty`. 

Squeak Terminal runs on Linux.

![Squeak Terminal running the opencode TUI](squeak-terminal.png)

## Features

- Run a **real interactive shell** over a pseudo-terminal
- Full VT100/VT102 + xterm emulation: cursor movement, scroll regions,
  insert/delete, **SGR colours** (16 and 256-colour palette), bold, underline,
  reverse
- **UTF-8** including box-drawing, block, shade, and arrow glyphs
- **Select, copy and paste**
- **Resizable**:

## Installation

Squeak Terminal is Linux-only and needs two native pieces at runtime, both
found through the Squeak FFI:

1. **libvterm** -- the terminal emulator. The Smalltalk side loads it by the bare
   module name `vterm`, so a file called `libvterm.so` must be resolvable. Either:
   - install the system package, e.g. on Debian/Ubuntu:
     `sudo apt install libvterm0` (or `libvterm-dev`), **or**
   - drop a `libvterm.so` **next to your image** (the VM searches the image
     directory). A copy of `libvterm.so` (Debian libvterm0 0.1.4) is included with
     the development image; you can reuse it.

2. **libc with `forkpty` / `openpty`** -- used to spawn the shell. Modern glibc
   (>= 2.34) includes these in `libc.so.6` itself, so nothing extra is needed on a
   typical Linux system.

Then load the Smalltalk code via Metacello:

```smalltalk
Metacello new
    baseline: 'SqueakTerminal';
    repository: 'github://hpi-swa-lab/squeak-terminal:main/src';
    load.
```

The Metacello package contains **only the Smalltalk code** -- it does not install
`libvterm.so`. If the library is missing, the first terminal you open will fail
with an FFI error; install libvterm (above) and retry.

To develop this package, use GitS.

## Usage

The main class is `SWATermMorph`. The quickest way in:

```smalltalk
SWATermMorph open.   "opens a terminal running bash in a window"
```

Or wire it up yourself:

```smalltalk
m := SWATermMorph new.
m openInWindow.
m startShell.
```

Run something other than bash:

```smalltalk
m startCommand: '/usr/bin/htop' args: #().
```

## Authors

* Jens Lincke, Software-Architecture Group, HPI, 2026

## AI Usage

* Created with the help of [SqueakMCP](https://github.com/hpi-swa-lab/squeak-mcp) / OpenCode / Claude Opus

## License

MIT -- see [LICENSE](LICENSE). The bundled `libvterm.so` is MIT-licensed
([neovim/libvterm](https://github.com/neovim/libvterm)); the bundled DejaVu Sans
Mono font is under its own permissive license.
