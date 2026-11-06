"
Owns a child shell attached to a Windows pseudo console (ConPTY) and the two
pipe ends that carry its I/O. The Windows counterpart of SWATermPty; same
protocol, so SWATermMorph can use either.

Usage:
  pty := SWATermConPty command: 'powershell.exe' args: #().
  pty spawnRows: 24 cols: 80.
  bytes := pty readAvailable.
  pty write: aByteArray.
  pty resizeRows: 24 cols: 80.
  pty close.

Windows has no forkpty and no non-blocking pipe mode. Reads are sized with
PeekNamedPipe first and only then issued, because a blocking ReadFile inside an
FFI call stops the whole VM rather than just the pump process.

Requires Windows 10 1809 (build 17763) or later.
"
Class {
	#name : #SWATermConPty,
	#superclass : #Object,
	#instVars : [
		'k',
		'hpcon',
		'childProcess',
		'childPid',
		'inWrite',
		'outRead',
		'command',
		'argv'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #'instance creation',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty class >> command: cmdString args: argArray [
	^ self new setCommand: cmdString args: argArray
]

{
	#category : #'class initialization',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty class >> initialize [
	" self initialize "

	Smalltalk addToStartUpList: self.
]

{
	#category : #'system startup',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty class >> startUp: resuming [
	"resuming = true: the image was loaded fresh from disk and every handle here
	 belongs to the dead previous process. resuming = false: same process, leave alone."
	resuming ifFalse: [ ^ self ].
	self allInstancesDo: [ :p | p beDead ]
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:29'
}
SWATermConPty >> attributeListFor: aPseudoConsole [
	"A one-entry process-thread attribute list binding the pseudo console to the
	 child. PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE_HANDLE = 0x00020016.
	 This attribute takes the HPCON itself as lpValue, not a pointer to it:
	 passing its address attaches no console, and the child then runs and exits
	 with its output going nowhere."
	| sizeOut bytes list |
	"Both calls take the same non-null lpSize: the first reports the size, the
	 second reads it back. Passing null the second time dereferences null."
	sizeOut := ExternalAddress allocate: 8.
	[ k initializeProcThreadAttributeList: nil count: 1 flags: 0 size: sizeOut.
	  bytes := sizeOut unsignedLongAt: 1.
	  bytes = 0 ifTrue: [ ^ self error: 'InitializeProcThreadAttributeList gave size 0' ].
	  list := ExternalAddress allocate: bytes.
	  (k initializeProcThreadAttributeList: list count: 1 flags: 0 size: sizeOut) = 0
		ifTrue: [ list free. ^ self error: 'InitializeProcThreadAttributeList failed: ', k getLastError printString ] ]
		ensure: [ sizeOut free ].
	(k updateProcThreadAttribute: list flags: 0 attribute: 16r00020016
		value: aPseudoConsole size: 8 previous: nil returnSize: nil) = 0
			ifTrue: [ list free. ^ self error: 'UpdateProcThreadAttribute failed' ].
	^ list
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> beDead [
	"Drop every handle WITHOUT closing it: after an image load these are numbers
	 from the previous process and Windows may have reused them."
	hpcon := nil.
	childProcess := nil.
	inWrite := nil.
	outRead := nil.
	childPid := -1.
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> childPid [
	^ childPid
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> close [
	"Order matters: ClosePseudoConsole waits for the attached client, so the child
	 goes first, and the output pipe stays readable until then so conhost cannot
	 block writing into a pipe nobody drains."
	(childProcess notNil and: [ childProcess isNull not ]) ifTrue: [
		k terminateProcess: childProcess exitCode: 0.
		k waitForSingleObject: childProcess timeout: 2000.
		self drainQuietly.
		k closeHandle: childProcess ].
	(hpcon notNil and: [ hpcon isNull not ]) ifTrue: [ k closePseudoConsole: hpcon ].
	(inWrite notNil and: [ inWrite isNull not ]) ifTrue: [ k closeHandle: inWrite ].
	(outRead notNil and: [ outRead isNull not ]) ifTrue: [ k closeHandle: outRead ].
	hpcon := nil. childProcess := nil. inWrite := nil. outRead := nil.
	childPid := -1.
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:15'
}
SWATermConPty >> command [
	^ command
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> commandLine [
	"One Windows command line from argv. Quote any argument containing a space."
	^ String streamContents: [ :s |
		argv doWithIndex: [ :arg :i |
			i > 1 ifTrue: [ s nextPut: $  ].
			(arg includes: $ )
				ifTrue: [ s nextPut: $"; nextPutAll: arg; nextPut: $" ]
				ifFalse: [ s nextPutAll: arg ] ] ]
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> coordRows: rows cols: cols [
	"COORD { SHORT X; SHORT Y } packed into one 32-bit register: X (cols) low."
	^ ((rows max: 1) bitShift: 16) + (cols max: 1)
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:22'
}
SWATermConPty >> createProcessWithList: attrList cmdLine: cmdLine [
	"STARTUPINFOEXW is a 104-byte STARTUPINFOW plus the attribute list pointer;
	 EXTENDED_STARTUPINFO_PRESENT = 0x00080000 tells CreateProcessW to read it.
	 Handles are inherited through the pseudo console, so bInheritHandles is false."
	| si pi ok thread |
	si := ByteArray new: 112.
	si unsignedLongAt: 1 put: 112 bigEndian: false.
	si unsignedLong64At: 105 put: attrList asInteger bigEndian: false.
	"PROCESS_INFORMATION on the C heap: its two handles are read back as
	 pointers, which no ByteArray offset can give us."
	pi := ExternalAddress allocate: 24.
	ok := k createProcessApp: nil cmdLine: cmdLine procAttrs: nil threadAttrs: nil
		inherit: 0 flags: 16r00080000 env: nil cwd: nil startupInfo: si procInfo: pi.
	ok = 0 ifTrue: [
		pi free.
		^ self error: 'CreateProcessW failed: ', k getLastError printString ].
	childProcess := self handleAt: 1 of: pi.
	thread := self handleAt: 9 of: pi.
	k closeHandle: thread.
	childPid := pi unsignedLongAt: 17.
	pi free.
	^ childPid
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> drainQuietly [
	"Discard whatever is still buffered, so ClosePseudoConsole is not held up by
	 a full output pipe."
	| avail n buf got |
	self isOpen ifFalse: [ ^ self ].
	avail := ByteArray new: 4.
	got := ByteArray new: 4.
	[ (k peekNamedPipe: outRead buffer: nil size: 0 read: nil avail: avail left: nil) = 0
		ifTrue: [ ^ self ].
	  n := (avail unsignedLongAt: 1 bigEndian: false) min: 4096.
	  n > 0 ] whileTrue: [
		buf := ByteArray new: n.
		(k readFile: outRead buffer: buf count: n read: got overlapped: nil) = 0
			ifTrue: [ ^ self ] ]
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:22'
}
SWATermConPty >> handleAt: offset of: anAddress [
	"Read a HANDLE stored at a byte offset in C memory. void* comes back wrapped
	 in an ExternalData; the address itself is in #getHandle."
	| v |
	v := anAddress pointerAt: offset.
	^ (v respondsTo: #getHandle) ifTrue: [ v getHandle ] ifFalse: [ v ]
]

{
	#category : #testing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> isOpen [
	^ outRead notNil and: [ outRead isNull not ]
]

{
	#category : #testing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> isRunning [
	"WAIT_TIMEOUT (258) means the child has not signalled, i.e. is still alive."
	(childProcess isNil or: [ childProcess isNull ]) ifTrue: [ ^ false ].
	^ (k waitForSingleObject: childProcess timeout: 0) = 258
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> masterFd [
	"Not an fd on Windows. SWATermMorph's pump loop polls this to decide whether
	 the PTY is still open, so answer the Unix convention: 0 alive, -1 closed."
	^ self isOpen ifTrue: [ 0 ] ifFalse: [ -1 ]
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> readAvailable [
	"Answer the child's pending output as a ByteArray (empty when idle), or nil
	 at EOF. PeekNamedPipe sizes the read so ReadFile never blocks the VM."
	| avail buf out n got |
	self isOpen ifFalse: [ ^ nil ].
	avail := ByteArray new: 4.
	got := ByteArray new: 4.
	out := WriteStream on: (ByteArray new: 4096).
	[ (k peekNamedPipe: outRead buffer: nil size: 0 read: nil avail: avail left: nil) = 0
		ifTrue: [ ^ out contents isEmpty ifTrue: [ nil ] ifFalse: [ out contents ] ].
	  n := (avail unsignedLongAt: 1 bigEndian: false) min: 4096.
	  n > 0 ] whileTrue: [
		buf := ByteArray new: n.
		(k readFile: outRead buffer: buf count: n read: got overlapped: nil) = 0
			ifTrue: [ ^ out contents isEmpty ifTrue: [ nil ] ifFalse: [ out contents ] ].
		out next: (got unsignedLongAt: 1 bigEndian: false) putAll: buf startingAt: 1 ].
	^ out contents
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> resizeRows: rows cols: cols [
	(hpcon isNil or: [ hpcon isNull ]) ifTrue: [ ^ self ].
	k resizePseudoConsole: hpcon size: (self coordRows: rows cols: cols).
]

{
	#category : #spawning,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> respawn: rows cols: cols [
	"Re-create the pseudo console and re-run the remembered command after a
	 snapshot, where beDead left command/argv but dropped the dead handles."
	command ifNil: [ ^ nil ].
	k := SWATermKernel32 default.
	argv ifNil: [ argv := (Array with: command) ].
	hpcon := nil. childProcess := nil. inWrite := nil. outRead := nil.
	childPid := -1.
	^ self spawnRows: rows cols: cols
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> setCommand: cmdString args: argArray [
	"argv[0] is conventionally the command itself, as in SWATermPty."
	k := SWATermKernel32 default.
	command := cmdString.
	argv := (Array with: cmdString), argArray.
	childPid := -1.
]

{
	#category : #spawning,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:29'
}
SWATermConPty >> spawnRows: rows cols: cols [
	"Create a pseudo console over two anonymous pipes, keep the parent ends, and
	 start the command attached to it. Answers the child pid."
	| outA outB inR outW hpconHolder attrList cmdLine pid |
	k := SWATermKernel32 default.
	outA := ExternalAddress allocate: 8.
	outB := ExternalAddress allocate: 8.
	hpconHolder := ExternalAddress allocate: 8.
	^ [ (k createPipeRead: outA write: outB attrs: nil size: 0) = 0
		ifTrue: [ ^ self error: 'CreatePipe failed: ', k getLastError printString ].
	  inR := self handleAt: 1 of: outA.
	  inWrite := self handleAt: 1 of: outB.
	  (k createPipeRead: outA write: outB attrs: nil size: 0) = 0
		ifTrue: [ ^ self error: 'CreatePipe failed: ', k getLastError printString ].
	  outRead := self handleAt: 1 of: outA.
	  outW := self handleAt: 1 of: outB.
	  (k createPseudoConsoleSize: (self coordRows: rows cols: cols)
		input: inR output: outW flags: 0 handle: hpconHolder) = 0
			ifFalse: [ ^ self error: 'CreatePseudoConsole failed' ].
	  hpcon := self handleAt: 1 of: hpconHolder.
	  "The pseudo console duplicated the child ends; ours would keep the pipes open."
	  k closeHandle: inR.
	  k closeHandle: outW.
	  attrList := self attributeListFor: hpcon.
	  cmdLine := self utf16zOf: self commandLine.
	  pid := self createProcessWithList: attrList cmdLine: cmdLine.
	  k deleteProcThreadAttributeList: attrList.
	  attrList free.
	  cmdLine free.
	  pid ] ensure: [ outA free. outB free. hpconHolder free ]
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> utf16zOf: aString [
	"Allocate aString as a null-terminated UTF-16LE string on the C heap.
	 CreateProcessW may write into its command line, so it cannot be a ByteArray."
	| addr i |
	addr := ExternalAddress allocate: (aString size + 1) * 2.
	1 to: aString size do: [ :n |
		i := (n - 1) * 2.
		addr unsignedByteAt: i + 1 put: ((aString at: n) asInteger bitAnd: 16rFF).
		addr unsignedByteAt: i + 2 put: ((aString at: n) asInteger bitShift: -8) ].
	addr unsignedByteAt: (aString size * 2) + 1 put: 0.
	addr unsignedByteAt: (aString size * 2) + 2 put: 0.
	^ addr
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:20'
}
SWATermConPty >> write: aByteArray [
	"Write keystrokes to the child's input pipe."
	| bytes written |
	(inWrite isNil or: [ inWrite isNull ]) ifTrue: [ ^ 0 ].
	bytes := aByteArray isString ifTrue: [ aByteArray asByteArray ] ifFalse: [ aByteArray ].
	bytes isEmpty ifTrue: [ ^ 0 ].
	written := ByteArray new: 4.
	(k writeFile: inWrite buffer: bytes count: bytes size written: written overlapped: nil) = 0
		ifTrue: [ ^ 0 ].
	^ written unsignedLongAt: 1 bigEndian: false
]
