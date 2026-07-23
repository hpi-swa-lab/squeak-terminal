"
FFI bindings to libvterm.so (VT100/VT102/xterm emulation library, https://github.com/neovim/libvterm).

The library does all VT parsing, screen buffering, SGR/color/mode handling. Smalltalk feeds bytes from a PTY via vterm_input_write: and reads back the screen grid via vterm_screen_get_cell:.

Module path: libvterm.so in the squeak working directory (copied from Debian libvterm0 0.1.4).

Handles (VTerm*, VTermScreen*, VTermState*) are opaque C pointers held as Smalltalk integers/ExternalAddress.

Typical flow:
  vt := SWAVTermLibrary default vterm_new_rows: 24 cols: 80.
  screen := SWAVTermLibrary default vterm_obtain_screen: vt.
  SWAVTermLibrary default vterm_screen_reset: screen hard: 1.
  SWAVTermLibrary default vterm_input: vt write: 'hi' size: 2.
  cell read via vterm_screen_get_cell.
"
Class {
	#name : #SWATermLibrary,
	#superclass : #ExternalLibrary,
	#classVars : [
		'Default'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:39'
}
SWATermLibrary class >> default [
	"Return the shared library instance."
	^ Default ifNil: [ Default := self new ]
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> unixModuleName [
	^ 'vterm'
]

{
	#category : #'api-keyboard',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm: vt keyboardKey: keyCode mod: modifiers [
	"void vterm_keyboard_key(VTerm *vt, VTermKey key, VTermModifier mod)
	 keyCode is a VTermKey enum (ENTER=1, TAB=2, BACKSPACE=3, ESCAPE=4, UP=5,
	 DOWN=6, LEFT=7, RIGHT=8, INS=9, DEL=10, HOME=11, END=12, PAGEUP=13, PAGEDOWN=14)."
	<cdecl: void 'vterm_keyboard_key' (void* int32_t int32_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-keyboard',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm: vt keyboardUnichar: codepoint mod: modifiers [
	"void vterm_keyboard_unichar(VTerm *vt, uint32_t c, VTermModifier mod)
	 Feeds a printable character keystroke; the encoded bytes appear in the output buffer."
	<cdecl: void 'vterm_keyboard_unichar' (void* uint32_t int32_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_free: vt [
	"void vterm_free(VTerm* vt) -- releases the emulator and its screen/state"
	<cdecl: void 'vterm_free' (void*) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_input: vt write: bytes size: len [
	"size_t vterm_input_write(VTerm *vt, const char *bytes, size_t len) -- feed PTY output into the emulator"
	<cdecl: size_t 'vterm_input_write' (void* char* size_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_new_rows: rows cols: cols [
	"VTerm *vterm_new(int rows, int cols) -- returns opaque VTerm* handle"
	<cdecl: void* 'vterm_new' (int32_t int32_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_obtain_screen: vt [
	"VTermScreen *vterm_obtain_screen(VTerm *vt)"
	<cdecl: void* 'vterm_obtain_screen' (void*) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_obtain_state: vt [
	"VTermState *vterm_obtain_state(VTerm *vt)"
	<cdecl: void* 'vterm_obtain_state' (void*) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_output_read: vt buffer: buf len: len [
	"size_t vterm_output_read(VTerm *vt, char *buffer, size_t len)
	 Drains pending output bytes (keyboard-encoded input + terminal replies) to send to the PTY."
	<cdecl: size_t 'vterm_output_read' (void* char* size_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-screen',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:33'
}
SWATermLibrary >> vterm_screen: screen getCellAt: pos into: cell [
	"int vterm_screen_get_cell(const VTermScreen *screen, VTermPos pos, VTermScreenCell *cell)
	 pos is passed BY VALUE (VTermPos struct). Returns 1 if cell present."
	<cdecl: int32_t 'vterm_screen_get_cell' (void* SWATermPos SWATermCell*) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-screen',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_screen_flush_damage: screen [
	"void vterm_screen_flush_damage(VTermScreen *screen)"
	<cdecl: void 'vterm_screen_flush_damage' (void*) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-screen',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_screen_reset: screen hard: hardInt [
	"void vterm_screen_reset(VTermScreen *screen, int hard) -- must be called before use"
	<cdecl: void 'vterm_screen_reset' (void* int32_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_set_size: vt rows: rows cols: cols [
	"void vterm_set_size(VTerm *vt, int rows, int cols)"
	<cdecl: void 'vterm_set_size' (void* int32_t int32_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-vterm',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:20'
}
SWATermLibrary >> vterm_set_utf8: vt enabled: flag [
	"void vterm_set_utf8(VTerm *vt, int is_utf8)"
	<cdecl: void 'vterm_set_utf8' (void* int32_t) module: 'vterm'>
	^ self externalCallFailed
]

{
	#category : #'api-state',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:33'
}
SWATermLibrary >> vterm_state: state getCursorPos: posOut [
	"void vterm_state_get_cursorpos(const VTermState *state, VTermPos *cursorpos)"
	<cdecl: void 'vterm_state_get_cursorpos' (void* SWATermPos*) module: 'vterm'>
	^ self externalCallFailed
]
