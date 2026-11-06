"
FFI bindings to the Win32 kernel32 functions needed to run a shell under a
pseudo console (ConPTY), the Windows counterpart of SWATermLibc's forkpty.

Windows has no forkpty: a child is attached to a pseudo console created with
CreatePseudoConsole, which is handed the child ends of two anonymous pipes and
passed to CreateProcessW through a process-thread attribute list. We keep the
parent ends: the read end carries the child's VT output (fed to libvterm), the
write end carries keystrokes.

COORD is a 4-byte struct passed by value. Both the x64 and the ARM64 Windows
ABIs pass such a struct in a single integer register, so it is declared
uint32_t here: cols in the low half, rows in the high half.

Requires Windows 10 1809 (build 17763) or later for the pseudo console API.
"
Class {
	#name : #SWATermKernel32,
	#superclass : #ExternalLibrary,
	#classVars : [
		'Default'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 class >> default [
	^ Default ifNil: [ Default := self new ]
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 15:16'
}
SWATermKernel32 class >> resetDefault [
	"Drop the shared instance, which after an image load was built by the dead
	 process. The next #default builds one against this process's modules."
	Default := nil
]

{
	#category : #'api-handle',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> closeHandle: handle [
	"BOOL CloseHandle(HANDLE)"
	<cdecl: int32_t 'CloseHandle' (void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-conpty',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> closePseudoConsole: hpcon [
	"void ClosePseudoConsole(HPCON) -- blocks until the attached child exits"
	<cdecl: void 'ClosePseudoConsole' (void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-pipe',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> createPipeRead: readHandlePtr write: writeHandlePtr attrs: sa size: bufSize [
	"BOOL CreatePipe(PHANDLE hRead, PHANDLE hWrite, LPSECURITY_ATTRIBUTES, DWORD nSize)"
	<cdecl: int32_t 'CreatePipe' (void* void* void* uint32_t) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> createProcessApp: appName cmdLine: cmdLine procAttrs: pa threadAttrs: ta inherit: inherit flags: flags env: env cwd: cwd startupInfo: si procInfo: pi [
	"BOOL CreateProcessW(...). cmdLine is UTF-16 and must be writable memory."
	<cdecl: int32_t 'CreateProcessW' (void* void* void* void* int32_t uint32_t void* void* void* void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-conpty',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> createPseudoConsoleSize: coord input: hInput output: hOutput flags: flags handle: hpconPtr [
	"HRESULT CreatePseudoConsole(COORD, HANDLE, HANDLE, DWORD, HPCON*)"
	<cdecl: int32_t 'CreatePseudoConsole' (uint32_t void* void* uint32_t void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> deleteProcThreadAttributeList: list [
	"void DeleteProcThreadAttributeList(LPPROC_THREAD_ATTRIBUTE_LIST)"
	<cdecl: void 'DeleteProcThreadAttributeList' (void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:46'
}
SWATermKernel32 >> getCurrentProcessId [
	"DWORD GetCurrentProcessId(void)"
	<cdecl: uint32_t 'GetCurrentProcessId' () module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-handle',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> getLastError [
	"DWORD GetLastError(void)"
	<cdecl: uint32_t 'GetLastError' () module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> initializeProcThreadAttributeList: list count: count flags: flags size: sizePtr [
	"BOOL InitializeProcThreadAttributeList(LPPROC_THREAD_ATTRIBUTE_LIST, DWORD, DWORD, PSIZE_T).
	 Called first with a null list to learn the required size."
	<cdecl: int32_t 'InitializeProcThreadAttributeList' (void* uint32_t uint32_t void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-pipe',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> peekNamedPipe: handle buffer: buf size: bufSize read: bytesReadPtr avail: totalAvailPtr left: leftPtr [
	"BOOL PeekNamedPipe(...). The only way to size a read without blocking:
	 anonymous pipes have no non-blocking mode, and a blocking ReadFile in an
	 FFI call stops the whole VM, not just the pump process."
	<cdecl: int32_t 'PeekNamedPipe' (void* void* uint32_t void* void* void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-pipe',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> readFile: handle buffer: buf count: count read: bytesReadPtr overlapped: ov [
	"BOOL ReadFile(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED)"
	<cdecl: int32_t 'ReadFile' (void* void* uint32_t void* void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-conpty',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> resizePseudoConsole: hpcon size: coord [
	"HRESULT ResizePseudoConsole(HPCON, COORD) -- the ConPTY equivalent of TIOCSWINSZ"
	<cdecl: int32_t 'ResizePseudoConsole' (void* uint32_t) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> terminateProcess: handle exitCode: code [
	"BOOL TerminateProcess(HANDLE, UINT)"
	<cdecl: int32_t 'TerminateProcess' (void* uint32_t) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:29'
}
SWATermKernel32 >> updateProcThreadAttribute: list flags: flags attribute: attr value: valuePtr size: valueSize previous: prev returnSize: retSize [
	"BOOL UpdateProcThreadAttribute(...). Whether lpValue is a value or a pointer
	 depends on the attribute; the pseudo console one takes the HPCON itself."
	<cdecl: int32_t 'UpdateProcThreadAttribute' (void* uint32_t uint64_t void* uint64_t void* void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-process',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> waitForSingleObject: handle timeout: ms [
	"DWORD WaitForSingleObject(HANDLE, DWORD) -- 258 (WAIT_TIMEOUT) means still running"
	<cdecl: uint32_t 'WaitForSingleObject' (void* uint32_t) module: 'kernel32.dll'>
	^ self externalCallFailed
]

{
	#category : #'api-pipe',
	#'squeak_changestamp' : 'MCPServer (SqueakXR) 11/6/2026 14:18'
}
SWATermKernel32 >> writeFile: handle buffer: buf count: count written: bytesWrittenPtr overlapped: ov [
	"BOOL WriteFile(HANDLE, LPCVOID, DWORD, LPDWORD, LPOVERLAPPED)"
	<cdecl: int32_t 'WriteFile' (void* void* uint32_t void* void*) module: 'kernel32.dll'>
	^ self externalCallFailed
]
