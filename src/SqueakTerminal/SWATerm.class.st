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
		'lib',
		'vt',
		'screen',
		'state',
		'rows',
		'cols',
		'ownerPid',
		'readPos',
		'readCell',
		'scrollback',
		'pushedLines',
		'sbCallbacks',
		'sbPushline'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:47'
}
SWATerm class >> currentProcessId [
	"The OS process id of the running VM. A reloaded image is a new process, which
	 is the only reliable way to tell a live handle from one saved by a dead one:
	 the ExternalAddresses themselves come back non-null across a snapshot."
	^ Smalltalk platformName = 'Win32'
		ifTrue: [ SWATermKernel32 default getCurrentProcessId ]
		ifFalse: [ SWATermLibc default getpid ]
]

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
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:08'
}
SWATerm >> cellsIn: rowBytes [
	| size |
	size := SWATermCell externalType byteSize.
	^ (1 to: rowBytes size by: size) collect: [ :i |
		SWATermCell fromHandle: (rowBytes copyFrom: i to: i + size - 1) ]
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:08'
}
SWATerm >> cellsOfRow: row [
	^ self cellsIn: (self rowBytes: row)
]

{
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> clearScrollback [
	scrollback := OrderedCollection new.
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
	#category : #input,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:42'
}
SWATerm >> endPaste [
	self isDead ifTrue: [ ^ self ].
	lib vterm_keyboard_end_paste: vt.
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
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> free [
	"Release the libvterm instance. Screen/state are owned by vt and freed with it."
	"If the terminal is dead (nil or snapshot-nulled handles) do NOT call
	 vterm_free: -- freeing a null/dangling pointer segfaults. Just drop refs."
	self isDead ifTrue: [ vt := nil. screen := nil. state := nil. ^ self ].
	lib vterm_free: vt. vt := nil. screen := nil. state := nil.
	sbCallbacks ifNotNil: [ sbCallbacks free. sbCallbacks := nil ].
	sbPushline ifNotNil: [ sbPushline free. sbPushline := nil ].
]

{
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> historyRowBytes: index [
	"Index 1 is the oldest line. Answers the row padded or cut to the current width."
	| stored size bytes |
	stored := scrollback at: index.
	size := SWATermCell externalType byteSize.
	stored size >= (cols * size) ifTrue: [ ^ stored copyFrom: 1 to: cols * size ].
	bytes := ByteArray new: cols * size.
	bytes replaceFrom: 1 to: stored size with: stored startingAt: 1.
	stored size + 1 to: bytes size by: size do: [ :i |
		bytes replaceFrom: i to: i + size - 1 with: stored startingAt: stored size - size + 1 ].
	^ bytes
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> initRows: r cols: c [
	rows := r.
	cols := c.
	ownerPid := self class currentProcessId.
	lib := SWATermLibrary default.
	vt := lib vterm_new_rows: r cols: c.
	lib vterm_set_utf8: vt enabled: 1.
	screen := lib vterm_obtain_screen: vt.
	state := lib vterm_obtain_state: vt.
	lib vterm_screen_reset: screen hard: 1.
	self installScrollback.
]

{
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> installScrollback [
	"libvterm keeps the pointer to the callbacks struct, so it lives in external memory as long as screen does.
	 sb_pushline is the seventh slot of VTermScreenCallbacks."
	scrollback ifNil: [ scrollback := OrderedCollection new ].
	pushedLines ifNil: [ pushedLines := 0 ].
	sbPushline := FFICallback
		signature: #(int32_t int32_t 'void*' 'void*')
		block: [ :n :cells :user |
			"An exception unwinding out of here cannot cross the C frame of vterm_input_write."
			[ self pushScrollbackCells: cells cols: n ] on: Error do: [ :e | ].
			1 ].
	sbCallbacks := ExternalAddress allocate: 10 * 8.
	1 to: 10 * 8 do: [ :i | sbCallbacks byteAt: i put: 0 ].
	sbCallbacks pointerAt: 6 * 8 + 1 put: sbPushline getHandle.
	lib vterm_screen: screen setCallbacks: sbCallbacks user: ExternalAddress new.
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
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:13'
}
SWATerm >> keyDelete [	^ 10
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyDown [	^ 6
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:13'
}
SWATerm >> keyEnd [	^ 12
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
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:13'
}
SWATerm >> keyHome [	^ 11
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:13'
}
SWATerm >> keyInsert [	^ 9
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:48'
}
SWATerm >> keyLeft [	^ 7
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:13'
}
SWATerm >> keyPageDown [	^ 14
]

{
	#category : #'input-keys',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:13'
}
SWATerm >> keyPageUp [	^ 13
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
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> maxScrollback [
	^ 5000
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:25'
}
SWATerm >> mouseButton: button pressed: aBoolean row: row col: col mod: modifiers [
	"libvterm buttons: 1 left, 2 middle, 3 right."
	self isDead ifTrue: [ ^ self ].
	lib vterm: vt mouseMoveRow: row col: col mod: modifiers.
	lib vterm: vt mouseButton: button pressed: aBoolean mod: modifiers.
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:25'
}
SWATerm >> mouseMoveRow: row col: col mod: modifiers [
	self isDead ifTrue: [ ^ self ].
	lib vterm: vt mouseMoveRow: row col: col mod: modifiers.
]

{
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> pushScrollbackCells: cells cols: n [
	"The cells are only valid during the callback. The trailing run of identical cells is dropped;
	 #historyRowBytes: restores it by repeating the last cell."
	| from size keep bytes |
	from := (cells isKindOf: ExternalStructure) ifTrue: [ cells getHandle ] ifFalse: [ cells ].
	size := SWATermCell externalType byteSize.
	keep := n.
	[ keep > 1 and: [ (1 to: size by: 8) allSatisfy: [ :o |
		(from unsignedLongLongAt: keep - 2 * size + o) = (from unsignedLongLongAt: n - 1 * size + o) ] ] ]
			whileTrue: [ keep := keep - 1 ].
	bytes := ByteArray new: keep * size.
	1 to: bytes size by: 8 do: [ :i | bytes unsignedLongLongAt: i put: (from unsignedLongLongAt: i) ].
	scrollback addLast: bytes.
	scrollback size > self maxScrollback ifTrue: [ scrollback removeFirst ].
	pushedLines := pushedLines + 1.
]

{
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> pushedLines [
	^ pushedLines ifNil: [ 0 ]
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
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:08'
}
SWATerm >> rowBytes: row [
	"The raw VTermScreenCells of a row, read through one reused pos and cell:
	 allocating an ExternalStructure costs ten times the FFI call."
	| size bytes |
	self isDead ifTrue: [ ^ ByteArray new ].
	(row between: 0 and: rows - 1) ifFalse: [ ^ ByteArray new ].
	size := SWATermCell externalType byteSize.
	readPos ifNil: [ readPos := SWATermPos new ].
	readCell ifNil: [ readCell := SWATermCell new ].
	bytes := ByteArray new: cols * size.
	readPos row: row.
	0 to: cols - 1 do: [ :col |
		readPos col: col.
		lib vterm_screen: screen getCellAt: readPos into: readCell.
		bytes replaceFrom: col * size + 1 to: col + 1 * size with: readCell getHandle startingAt: 1 ].
	^ bytes
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 17:29'
}
SWATerm >> rowCodepointsInto: aByteArray row: row [
	"Read every cell's primary codepoint on 0-based row into aByteArray (which
	 must hold cols * 4 bytes) as little-endian uint32s, in one FFI call. Answer
	 the number of codepoints written. Much cheaper than one get_cell per cell."
	| rect |
	self isDead ifTrue: [ ^ 0 ].
	(row between: 0 and: rows - 1) ifFalse: [ ^ 0 ].
	rect := SWATermRect new.
	rect startRow: row; endRow: row + 1; startCol: 0; endCol: cols.
	^ lib vterm_screen: screen getChars: aByteArray len: cols rect: rect
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

{
	#category : #scrollback,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATerm >> scrollbackSize [
	^ scrollback ifNil: [ 0 ] ifNotNil: [ scrollback size ]
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:42'
}
SWATerm >> startPaste [
	self isDead ifTrue: [ ^ self ].
	lib vterm_keyboard_start_paste: vt.
]

{
	#category : #testing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:47'
}
SWATerm >> validateProcess [
	"Kill the handles if they were made by a previous VM process, and answer
	 whether this terminal is now dead. Call once per draw or pump iteration,
	 never per cell: it costs one FFI call.
	 Do not rely on the startUp: hooks for this -- they sit at the end of a long
	 startup list and never run if an earlier entry raises."
	| pid |
	pid := self class currentProcessId.
	ownerPid ifNil: [ ownerPid := pid ].
	ownerPid = pid ifFalse: [ self beDead ].
	^ self isDead
]

{
	#category : #input,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 13:37'
}
SWATerm >> wheelUp: up row: row col: col mod: modifiers [
	"libvterm only encodes this when the application enabled mouse reporting."
	self isDead ifTrue: [ ^ self ].
	lib vterm: vt mouseMoveRow: row col: col mod: modifiers.
	lib vterm: vt mouseButton: (up ifTrue: [ 4 ] ifFalse: [ 5 ]) pressed: true mod: modifiers.
]
