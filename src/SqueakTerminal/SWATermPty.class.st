"
Owns a forkpty'd child shell and its PTY master fd.

Usage:
  pty := SWATermPty command: '/bin/bash' args: #('-i').
  pty spawn.                 -- forkpty + execvp in child
  bytes := pty readAvailable.-- non-blocking read from master
  pty write: aByteArray.     -- write keystrokes to master
  pty resizeRows: 24 cols: 80.
  pty close.

The child inherits the PTY slave as stdin/stdout/stderr with a controlling tty,
so interactive programs (bash, vim) work.

IMPORTANT: the master fd is set non-blocking so #readAvailable never stalls the
image; the pump loop (in SWATermMorph) polls it.
"
Class {
	#name : #SWATermPty,
	#superclass : #Object,
	#instVars : [
		'masterFd',
		'childPid',
		'lib',
		'command',
		'argv',
		'argvBuf',
		'cstrings'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #'instance creation',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty class >> command: cmdString args: argArray [
	^ self new setCommand: cmdString args: argArray
]

{
	#category : #'class initialization',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:50'
}
SWATermPty class >> initialize [
	" self initialize "

	Smalltalk addToStartUpList: self.
]

{
	#category : #'system startup',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:50'
}
SWATermPty class >> startUp: resuming [
	"resuming = true: image loaded fresh from disk. Every PTY's fd/pid/buffers
	 belong to the dead previous process -- mark them dead so close won't touch
	 a stale fd or kill a reused pid. resuming = false: same process, leave alone."
	resuming ifFalse: [ ^ self ].
	self allInstancesDo: [ :p | p beDead ]
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> allocCString: aString [
	"Allocate a null-terminated C string on the C heap; return its ExternalAddress."
	| bytes addr |
	bytes := aString asByteArray.
	addr := ExternalAddress allocate: bytes size + 1.
	1 to: bytes size do: [ :i | addr unsignedByteAt: i put: (bytes at: i) ].
	addr unsignedByteAt: bytes size + 1 put: 0.
	^ addr
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:50'
}
SWATermPty >> beDead [
	"Mark this PTY dead, idempotently. After an image load the fd/pid belong to
	 the previous process (the OS may have reused the pid) and the C buffers are
	 dangling. Reset fd/pid to -1 so close won't close:/kill: a stale/reused
	 target, and drop the buffer refs WITHOUT freeing (the pointers are dead)."
	masterFd := -1.
	childPid := -1.
	argvBuf := nil.
	cstrings := nil
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> buildArgv [
	"Build a C char*[] for execvp: one null-terminated C string per arg,
	 plus a pointer array terminated by a null pointer. All memory is allocated
	 on the C heap BEFORE fork so the child does no Smalltalk allocation."
	| ptrSize |
	ptrSize := ExternalAddress wordSize.	"8 on 64-bit"
	cstrings := argv collect: [ :s |
		| bytes addr |
		bytes := s asByteArray.
		addr := ExternalAddress allocate: bytes size + 1.
		1 to: bytes size do: [ :i | addr unsignedByteAt: i put: (bytes at: i) ].
		addr unsignedByteAt: bytes size + 1 put: 0.
		addr ].
	"pointer array: argv count + 1 (null terminator)"
	argvBuf := ExternalAddress allocate: (cstrings size + 1) * ptrSize.
	cstrings doWithIndex: [ :addr :i |
		argvBuf pointerAt: ((i - 1) * ptrSize) + 1 put: addr ].
	argvBuf pointerAt: (cstrings size * ptrSize) + 1 put: (ExternalAddress new).
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:53'
}
SWATermPty >> childPid [
	^ childPid
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> close [
	"Close the master fd and terminate the child."
	masterFd >= 0 ifTrue: [ lib close: masterFd. masterFd := -1 ].
	childPid > 0 ifTrue: [ lib kill: childPid signal: 1. childPid := -1 ].	"SIGHUP"
	self freeBuffers.
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 18:48'
}
SWATermPty >> freeBuffers [
	"After a snapshot these ExternalAddresses are null/dead: freeing them fails.
	 Only free a still-valid (non-null) address; otherwise just drop the ref."
	cstrings ifNotNil: [ cstrings do: [ :a | (a notNil and: [ a isNull not ]) ifTrue: [ a free ] ]. cstrings := nil ].
	(argvBuf notNil and: [ argvBuf isNull not ]) ifTrue: [ argvBuf free ].
	argvBuf := nil.
]

{
	#category : #testing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:53'
}
SWATermPty >> isRunning [
	"True if the child is still alive (waitpid WNOHANG returns 0)."
	| status r |
	childPid <= 0 ifTrue: [ ^ false ].
	status := ByteArray new: 4.
	r := lib waitpid: childPid status: status options: 1.	"WNOHANG"
	^ r = 0
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:53'
}
SWATermPty >> masterFd [
	^ masterFd
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> readAvailable [
	"Non-blocking read of pending PTY output. Returns a ByteArray (possibly empty),
	 or nil if the child has closed the PTY (EOF)."
	| buf n out |
	masterFd < 0 ifTrue: [ ^ nil ].
	buf := ByteArray new: 4096.
	out := WriteStream on: (ByteArray new: 4096).
	[ n := lib read: masterFd buf: buf count: buf size.
	  n > 0 ] whileTrue: [
		out next: n putAll: buf startingAt: 1.
		n < buf size ifTrue: [ ^ out contents ] ].
	n = 0 ifTrue: [ ^ out contents isEmpty ifTrue: [ nil ] ifFalse: [ out contents ] ].
	"n < 0: EAGAIN (no data) is normal for non-blocking; return what we have."
	^ out contents
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> resizeRows: rows cols: cols [
	"Tell the kernel the new window size (TIOCSWINSZ = 0x5414) so the child gets SIGWINCH."
	| ws |
	masterFd < 0 ifTrue: [ ^ self ].
	ws := self winsizeStructRows: rows cols: cols.
	lib ioctl: masterFd request: 16r5414 arg: ws.
]

{
	#category : #spawning,
	#'squeak_changestamp' : 'MCPServer 7/24/2026 14:45'
}
SWATermPty >> respawn: rows cols: cols [
	"Re-fork the remembered command/argv after a snapshot (beDead left them
	 intact but reset fd/pid to -1 and dropped the C buffers). Rebuilds the C
	 argv and forkpty's a fresh child sized to the given grid. Answers the new
	 pid, or nil if there is nothing to respawn (no command remembered)."
	command ifNil: [ ^ nil ].
	lib := SWATermLibc default.
	argv ifNil: [ argv := (Array with: command) ].
	masterFd := -1.
	childPid := -1.
	argvBuf := nil.
	cstrings := nil.
	^ self spawnRows: rows cols: cols
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:34'
}
SWATermPty >> setCommand: cmdString args: argArray [
	"Store command and its arguments; argv[0] conventionally is the command itself."
	lib := SWATermLibc default.
	command := cmdString.
	argv := (Array with: cmdString), argArray.
	masterFd := -1.
	childPid := -1.
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> setNonBlocking [
	"Set O_NONBLOCK on the master fd. F_GETFL=3, F_SETFL=4, O_NONBLOCK=2048 (0o4000) on Linux."
	| flags |
	flags := lib fcntl: masterFd cmd: 3 arg: 0.
	lib fcntl: masterFd cmd: 4 arg: (flags bitOr: 2048).
]

{
	#category : #spawning,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> spawnRows: rows cols: cols [
	"forkpty a child, exec the shell in it, keep the master fd on the parent side.
	 Everything the child touches (argv, cmd C-string, winsize) is allocated before fork."
	| amaster winsize cmdCStr pid |
	self buildArgv.
	cmdCStr := self allocCString: command.
	amaster := ByteArray new: 4.
	winsize := self winsizeStructRows: rows cols: cols.
	pid := lib forkpty: amaster name: nil termios: nil winsize: winsize.
	pid = 0 ifTrue: [
		"CHILD: replace image with the shell. Do NOT allocate or run Smalltalk."
		lib execvp: cmdCStr argv: argvBuf.
		"execvp only returns on failure; abort the doomed child hard."
		lib kill: 0 signal: 9.
		^ nil ].
	pid < 0 ifTrue: [ ^ self error: 'forkpty failed' ].
	"PARENT"
	childPid := pid.
	masterFd := amaster unsignedLongAt: 1.
	self setNonBlocking.
	^ pid
]

{
	#category : #private,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> winsizeStructRows: rows cols: cols [
	"struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; } -- 8 bytes.
	 Returned as a ByteArray (little-endian) suitable to pass as void*."
	| ba |
	ba := ByteArray new: 8.
	ba unsignedShortAt: 1 put: rows bigEndian: false.
	ba unsignedShortAt: 3 put: cols bigEndian: false.
	^ ba
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:52'
}
SWATermPty >> write: aByteArray [
	"Write bytes to the PTY master (child's stdin)."
	| bytes |
	masterFd < 0 ifTrue: [ ^ 0 ].
	bytes := aByteArray isString ifTrue: [ aByteArray asByteArray ] ifFalse: [ aByteArray ].
	bytes isEmpty ifTrue: [ ^ 0 ].
	^ lib write: masterFd buf: bytes count: bytes size
]
