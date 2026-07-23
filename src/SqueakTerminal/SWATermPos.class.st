"
FFI mapping of libvterm's VTermPos struct:
  typedef struct { int row; int col; } VTermPos;
Used as a by-value argument to vterm_screen_get_cell and as out-param for cursor position.
"
Class {
	#name : #SWATermPos,
	#superclass : #ExternalStructure,
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #'field definition',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:40'
}
SWATermPos class >> fields [
	"VTermPos: { int row; int col; }"
	^ #(
		(row 'long')
		(col 'long')
	)
]
