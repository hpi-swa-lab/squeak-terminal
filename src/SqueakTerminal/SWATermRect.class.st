"
A VTermRect passed by value to libvterm bulk-readout calls.
C layout: struct { int start_row; int end_row; int start_col; int end_col; }
Note the field order: rows first (start,end), then cols (start,end). end is exclusive.
"
Class {
	#name : #SWATermRect,
	#superclass : #ExternalStructure,
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #'as yet unclassified',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 17:29'
}
SWATermRect class >> fields [
	"VTermRect: { int start_row; int end_row; int start_col; int end_col; }"
	^ #(
		(startRow 'long')
		(endRow 'long')
		(startCol 'long')
		(endCol 'long')
	)
]
