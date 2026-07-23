"
Minimal FFI bindings to the C standard library (libc.so.6) needed to run a
pseudo-terminal shell for SWATerminal.

Functions: forkpty, execvp, read, write, close, ioctl (TIOCSWINSZ),
fcntl (set non-blocking), waitpid, kill.

On modern glibc (>=2.34) forkpty/openpty live in libc itself, so we bind the
single module libc.so.6.

forkpty returns the child pid to the parent and 0 to the child; in the child
we must immediately execvp the shell. The master fd (out-param) is the PTY we
read/write from the image side.
"
Class {
	#name : #SWATermLibc,
	#superclass : #ExternalLibrary,
	#classVars : [
		'Default'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:51'
}
SWATermLibc class >> default [
	^ Default ifNil: [ Default := self new ]
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> close: fd [
	"int close(int fd)"
	<cdecl: int32_t 'close' (int32_t) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #pty,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> execvp: fileNamePtr argv: argvPtr [
	"int execvp(const char *file, char *const argv[])
	 Only returns (with -1) on error; on success it replaces the process image."
	<cdecl: int32_t 'execvp' (char* void*) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> fcntl: fd cmd: cmd arg: arg [
	"int fcntl(int fd, int cmd, int arg). Used to set O_NONBLOCK: cmd F_SETFL(4), arg O_NONBLOCK(2048)."
	<cdecl: int32_t 'fcntl' (int32_t int32_t int32_t) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #pty,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> forkpty: amasterPtr name: namePtr termios: termPtr winsize: winPtr [
	"pid_t forkpty(int *amaster, char *name, const struct termios *termp, const struct winsize *winp)
	 Returns child pid to parent, 0 to child, -1 on error.
	 amasterPtr: a 4-byte ByteArray receiving the master fd (parent side)."
	<cdecl: long 'forkpty' (int32_t* char* void* void*) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> ioctl: fd request: request arg: argPtr [
	"int ioctl(int fd, unsigned long request, void *arg). For TIOCSWINSZ(0x5414) with a winsize struct."
	<cdecl: int32_t 'ioctl' (int32_t ulong void*) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #process,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> kill: pid signal: sig [
	"int kill(pid_t pid, int sig). SIGHUP=1, SIGKILL=9, SIGTERM=15."
	<cdecl: int32_t 'kill' (long int32_t) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> read: fd buf: bufPtr count: count [
	"ssize_t read(int fd, void *buf, size_t count). Returns bytes read, 0 at EOF, -1 on error/EAGAIN."
	<cdecl: long 'read' (int32_t char* size_t) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #process,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> waitpid: pid status: statusPtr options: options [
	"pid_t waitpid(pid_t pid, int *status, int options). options WNOHANG=1."
	<cdecl: long 'waitpid' (long int32_t* int32_t) module: 'libc.so.6'>
	^ self externalCallFailed
]

{
	#category : #io,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:21'
}
SWATermLibc >> write: fd buf: bufPtr count: count [
	"ssize_t write(int fd, const void *buf, size_t count)"
	<cdecl: long 'write' (int32_t char* size_t) module: 'libc.so.6'>
	^ self externalCallFailed
]
