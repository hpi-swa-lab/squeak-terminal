"
High-level wrapper around a libvterm instance (via SWATermLibrary).

Owns the VTerm / VTermScreen / VTermState handles and the grid dimensions.
Feed emulator with PTY output via #feed:, read the grid via #cellAt:at:,
query the cursor via #cursorPos, send keystrokes via #keyChar:/#keyCode:,
and drain the bytes to write back to the PTY via #drainOutput.

This class knows nothing about Morphic or the PTY -- it is the pure
terminal-emulation model. SWATermMorph is the view; a PTY backend
drives #feed: and consumes #drainOutput.

Create with:  SWATerm rows: 24 cols: 80
"
Class {
	#name : #SWATerm,
	#superclass : #Object,
	#instVars : [
		'vt',
		'screen',
		'state',
		'rows',
		'cols',
		'lib'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #'class initialization',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:45'
}
SWATerm class >> initialize [
	" self initialize "

	Smalltalk addToStartUpList: self.
]

{
	#category : #'instance creation',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:47'
}
SWATerm class >> rows: r cols: c [
	^ self new initRows: r cols: c
]

{
	#category : #'system startup',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:45'
}
SWATerm class >> startUp: resuming [
	"resuming = true means the image was just loaded fresh from disk: every
	 libvterm handle belongs to the previous process and is dead. Mark every
	 terminal dead so all FFI methods bail (isDead) instead of segfaulting.
	 resuming = false is a same-process continuation -- handles are still valid,
	 leave them alone."
	resuming ifFalse: [ ^ self ].
	self allInstancesDo: [ :t | t beDead ]
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:39'
}
SWATerm >> beDead [
	"Mark this terminal's libvterm handles dead, idempotently. Safe to call any
	 number of times and in any state (nil, live ExternalData, already null).
	 Nulls the underlying ExternalAddress so isDead answers true but the ivars
	 keep their shape. Does NOT call vterm_free: (the pointer may be dangling)."
	#(vt screen state) do: [ :ivar | | h |
		h := self instVarNamed: ivar.
		h ifNotNil: [
			(h respondsTo: #getHandle)
				ifTrue: [ h getHandle isNull ifFalse: [ h getHandle beNull ] ]
				ifFalse: [ (h respondsTo: #beNull) ifTrue: [ h isNull ifFalse: [ h beNull ] ] ] ] ]
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:28'
}
SWATerm >> cellAt: row at: col [
	"Return a fresh SWATermCell for the given 0-based row/col, or nil if out of range."
	| pos cell |
	self isDead ifTrue: [ ^ nil ].
	(row between: 0 and: rows - 1) ifFalse: [ ^ nil ].
	(col between: 0 and: cols - 1) ifFalse: [ ^ nil ].
	pos := SWATermPos new.
	pos row: row; col: col.
	cell := SWATermCell new.
	lib vterm_screen: screen getCellAt: pos into: cell.
	^ cell
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:47'
}
SWATerm >> cols [
	^ cols
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:29'
}
SWATerm >> cursorPos [
	"Return the cursor position as a Point (col @ row), 0-based."
	| pos |
	self isDead ifTrue: [ ^ 0 @ 0 ].
	pos := SWATermPos new.
	lib vterm_state: state getCursorPos: pos.
	^ pos col @ pos row
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:29'
}
SWATerm >> drainOutput [
	"Read all pending encoded output bytes (from keystrokes / terminal replies).
	 Returns a ByteArray to be written to the PTY, or empty if none."
	| buf n out total |
	self isDead ifTrue: [ ^ #[] ].
	buf := ByteArray new: 256.
	out := WriteStream on: (ByteArray new: 64).
	total := 0.
	[ n := lib vterm_output_read: vt buffer: buf len: buf size.
	  n > 0 ] whileTrue: [
		1 to: n do: [ :i | out nextPut: (buf at: i) ].
		total := total + n.
		n < buf size ifTrue: [ ^ out contents ] ].
	^ out contents
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:29'
}
SWATerm >> feed: aByteArrayOrString [
	"Feed raw PTY output bytes into the emulator, then flush pending damage
	 so the screen grid reflects the new state."
	| bytes |
	self isDead ifTrue: [ ^ 0 ].
	bytes := aByteArrayOrString isString
		ifTrue: [
			"Raw PTY output is already UTF-8 bytes (a ByteString): pass through
			 untouched. A WideString of Smalltalk text must be UTF-8 encoded so
			 codepoints > 255 (box-drawing, arrows, emoji) reach libvterm correctly."
			aByteArrayOrString isByteString
				ifTrue: [ aByteArrayOrString asByteArray ]
				ifFalse: [ aByteArrayOrString utf8Encoded ] ]
		ifFalse: [ aByteArrayOrString ].
	bytes isEmpty ifTrue: [ ^ 0 ].
	lib vterm_input: vt write: bytes size: bytes size.
	lib vterm_screen_flush_damage: screen.
	^ bytes size
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:42'
}
SWATerm >> free [
	"Release the libvterm instance. Screen/state are owned by vt and freed with it."
	"If the terminal is dead (nil or snapshot-nulled handles) do NOT call
	 vterm_free: -- freeing a null/dangling pointer segfaults. Just drop refs."
	self isDead ifTrue: [ vt := nil. screen := nil. state := nil. ^ self ].
	lib vterm_free: vt. vt := nil. screen := nil. state := nil
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:35'
}
SWATerm >> initRows: r cols: c [
	rows := r.
	cols := c.
	lib := SWATermLibrary default.
	vt := lib vterm_new_rows: r cols: c.
	lib vterm_set_utf8: vt enabled: 1.
	screen := lib vterm_obtain_screen: vt.
	state := lib vterm_obtain_state: vt.
	lib vterm_screen_reset: screen hard: 1.
]

{
	#category : #testing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:28'
}
SWATerm >> isDead [
	"True when the libvterm handles are unusable: either wiped to nil, or the VM
	 nulled the ExternalAddress across a snapshot (isNull). Every FFI method that
	 dereferences vt/screen/state must bail when this is true, otherwise libvterm
	 segfaults on a freshly loaded image."
	(vt isNil or: [ screen isNil or: [ state isNil ] ]) ifTrue: [ ^ true ].
	^ vt getHandle isNull
		or: [ screen getHandle isNull
		or: [ state getHandle isNull ] ]
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyBackspace [	^ 3
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:29'
}
SWATerm >> keyChar: aCharacter mod: modifiers [
	"Send a printable character keystroke. Bytes accumulate in the output buffer;
	 caller then #drainOutput to forward to the PTY."
	self isDead ifTrue: [ ^ self ].
	lib vterm: vt keyboardUnichar: aCharacter asInteger mod: modifiers
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:29'
}
SWATerm >> keyCode: vtermKey mod: modifiers [
	"Send a special key (a VTermKey enum value; see #keyEnter etc.)."
	self isDead ifTrue: [ ^ self ].
	lib vterm: vt keyboardKey: vtermKey mod: modifiers
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyDown [	^ 6
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyEnter [	^ 1
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyEscape [	^ 4
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyLeft [	^ 7
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyRight [	^ 8
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyTab [	^ 2
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyUp [	^ 5
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/24/2026 14:45'
}
SWATerm >> reinit [
	"Rebuild the libvterm emulator from scratch after a snapshot wiped the
	 handles (see beDead). Keeps the remembered grid size (rows/cols). Does NOT
	 free the old vt/screen/state -- they are dangling pointers from the dead
	 previous process (already nulled by beDead); we simply install fresh ones.
	 After this isDead answers false and the terminal is usable again."
	self initRows: (rows ifNil: [ 24 ]) cols: (cols ifNil: [ 80 ])
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:29'
}
SWATerm >> resizeRows: r cols: c [
	rows := r.
	cols := c.
	self isDead ifTrue: [ ^ self ].
	lib vterm_set_size: vt rows: r cols: c.
	lib vterm_screen_flush_damage: screen.
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> rowString: row [
	"Return the plain text of a row as a String (for debugging/tests)."
	^ String streamContents: [ :s |
		0 to: cols - 1 do: [ :col |
			s nextPut: (self cellAt: row at: col) character ] ]
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:47'
}
SWATerm >> rows [
	^ rows
]
