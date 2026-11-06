"
FFI bindings to libvterm.so (VT100/VT102/xterm emulation library, https://github.com/neovim/libvterm).

The library does all VT parsing, screen buffering, SGR/color/mode handling. Smalltalk feeds bytes from a PTY via vterm_input_write: and reads back the screen grid via vterm_screen_get_cell:.

Loaded by the bare module name 'vterm' (libvterm.so, copied from Debian libvterm0 0.1.4, sitting next to the image).

Handles (VTerm*, VTermScreen*, VTermState*) are opaque C pointers held as Smalltalk integers/ExternalAddress.

Typical flow:
  vt := SWATermLibrary default vterm_new_rows: 24 cols: 80.
  screen := SWATermLibrary default vterm_obtain_screen: vt.
  SWATermLibrary default vterm_screen_reset: screen hard: 1.
  SWATermLibrary default vterm_input: vt write: 'hi' size: 2.
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
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> archiveMemberPath [
	"Path of the DLL inside the MSYS2 package."
	^ self isAarch64
		ifTrue: [ 'clangarm64/bin/libvterm-0.dll' ]
		ifFalse: [ 'mingw64/bin/libvterm-0.dll' ]
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:27'
}
SWATermLibrary class >> cleanUpScratch: archivePath extracted: extractedPath [
	"Remove the download and the whole directory tree tar unpacked beside the
	 image; only the installed copy should survive."
	| dir top |
	dir := FileDirectory default.
	dir deleteFileNamed: archivePath ifAbsent: [ nil ].
	dir deleteFileNamed: extractedPath ifAbsent: [ nil ].
	top := (FileDirectory on: Smalltalk imagePath) / (self archiveMemberPath copyUpTo: $/).
	top exists ifTrue: [ top recursiveDelete ]
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> confirmAndDownload [
	"Ask before fetching anything from the network, as the font install does."
	(self confirm: ('The terminal needs {1} ({2}), which is not installed next to the VM.
Download it now from the MSYS2 mirror?
({3})' format: { self libraryFileName.
		self isAarch64 ifTrue: [ 'ARM64' ] ifFalse: [ 'x86-64' ].
		self downloadUrl }))
		ifFalse: [ self logLine: 'download declined by user'. ^ false ].
	^ [ self downloadAndExtractTo: (self libraryDirectory fullNameFor: self libraryFileName) ]
		on: Error
		do: [ :e | self logLine: 'download failed: ', e messageText. false ]
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:39'
}
SWATermLibrary class >> default [
	"Return the shared library instance."
	^ Default ifNil: [ Default := self new ]
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> downloadAndExtractTo: destPath [
	"Fetch the MSYS2 package and put just the DLL at destPath. curl and tar both
	 ship with Windows 10/11, and that tar is bsdtar, which reads .zst; the image
	 has no zstd of its own. Answer true when the file is there.
	 Raises nothing itself: the caller decides how to report failure."
	| scratch archive member extracted |
	scratch := Smalltalk imagePath.
	archive := scratch, '\libvterm-download.pkg.tar.zst'.
	member := self archiveMemberPath.
	extracted := scratch, '\', (member copyReplaceAll: '/' with: '\').
	self logLine: 'downloading ', self downloadUrl.
	OSProcess waitForCommand: 'cmd.exe /c curl.exe -fsSL "', self downloadUrl,
		'" -o "', archive,
		'" && tar.exe -xf "', archive, '" -C "', scratch, '" "', member,
		'" && copy /y "', extracted, '" "', destPath, '"'.
	self waitForFile: destPath.
	self cleanUpScratch: archive extracted: extracted.
	^ FileDirectory default fileExists: destPath
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> downloadUrl [
	"MSYS2 ships libvterm for both Windows architectures; the repository differs
	 per CPU."
	^ self isAarch64
		ifTrue: [ 'https://mirror.msys2.org/mingw/clangarm64/mingw-w64-clang-aarch64-libvterm-0.3.3-1-any.pkg.tar.zst' ]
		ifFalse: [ 'https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-libvterm-0.3.3-1-any.pkg.tar.zst' ]
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> ensureInstalled [
	"Make libvterm available before anything calls into it. Answer false when the
	 terminal cannot run, so the caller can decline to open one: without the
	 library even creating a SWATerm fails."
	self isInstalled ifTrue: [ ^ true ].
	Smalltalk platformName = 'Win32' ifFalse: [
		self logLine: self libraryFileName, ' missing; install libvterm with the system package manager'.
		^ false ].
	^ self confirmAndDownload
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> isAarch64 [
	"An x86_64 DLL cannot load into an ARM64 process, and the failure reads as
	 'External module not found' -- the same message a missing file gives."
	^ (Smalltalk getSystemAttribute: 1003) asLowercase includesSubstring: 'aarch64'
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> isInstalled [
	^ self libraryDirectory fileExists: self libraryFileName
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> libraryDirectory [
	"Where the VM looks the module up. Confirmed by asking Windows which file
	 the running process actually loaded: the VM's own directory, not the
	 image's."
	^ FileDirectory on: Smalltalk vmPath
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> libraryFileName [
	"The file the bare module name 'vterm' in the cdecls resolves to here."
	^ Smalltalk platformName = 'Win32'
		ifTrue: [ 'vterm.dll' ]
		ifFalse: [ 'libvterm.so' ]
]

{
	#category : #support,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> logLine: aString [
	"Progress line to the Transcript during the library check/download."
	Transcript showln: 'SWATerm library: ', aString
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:16'
}
SWATermLibrary class >> resetDefault [
	"Drop the shared instance, which after an image load was built by the dead
	 process. The next #default builds one against this process's modules."
	Default := nil
]

{
	#category : #installing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:26'
}
SWATermLibrary class >> waitForFile: aPath [
	"OSProcess answers before the shell has necessarily finished writing, so give
	 the download a bounded chance to appear rather than guessing a delay."
	30 timesRepeat: [
		(FileDirectory default fileExists: aPath) ifTrue: [ ^ true ].
		(Delay forMilliseconds: 500) wait ].
	^ false
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
	#'squeak_changestamp' : 'MCPServer 7/27/2026 17:30'
}
SWATermLibrary >> vterm_screen: screen getChars: chars len: len rect: rect [
	"size_t vterm_screen_get_chars(const VTermScreen *screen, uint32_t *chars,
	 size_t len, const VTermRect rect)
	 Reads the primary codepoints of every cell in rect into the chars buffer
	 (one uint32 per cell, reading order). rect is passed BY VALUE. Answers the
	 number of codepoints that would be written (may exceed len)."
	<cdecl: size_t 'vterm_screen_get_chars' (void* char* size_t SWATermRect) module: 'vterm'>
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
