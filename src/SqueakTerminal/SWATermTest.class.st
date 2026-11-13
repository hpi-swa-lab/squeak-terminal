Class {
	#name : #SWATermTest,
	#superclass : #TestCase,
	#instVars : [
		'terminal'
	],
	#category : #'SqueakTerminal-Tests'
}

{
	#category : #support,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> escape: aString [
	^ (String with: Character escape), aString
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> setUp [
	terminal := SWATerm rows: 5 cols: 10.
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> tearDown [
	terminal free.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testApplicationCursorKeys [
	"Full-screen programs like mc switch the arrows to SS3 sequences."
	terminal feed: (self escape: '[?1h').
	terminal keyCode: terminal keyUp mod: 0.
	self assert: (self escape: 'OA') equals: terminal drainOutput asString.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testAttributes [
	| cell |
	terminal feed: (self escape: '[1;4;7m'), 'X', (self escape: '[0m'), 'Y'.
	cell := terminal cellAt: 0 at: 0.
	self assert: cell bold.
	self assert: cell underline > 0.
	self assert: cell reverse.
	cell := terminal cellAt: 0 at: 1.
	self deny: cell bold.
	self assert: 0 equals: cell underline.
	self deny: cell reverse.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testBeDeadThenReinit [
	terminal feed: 'x'.
	terminal free.
	terminal beDead.
	terminal reinit.
	self deny: terminal isDead.
	self assert: 5 equals: terminal rows.
	self assert: 10 equals: terminal cols.
	self assert: '          ' equals: (terminal rowString: 0).
	terminal feed: 'y'.
	self assert: $y equals: (terminal cellAt: 0 at: 0) character.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testCarriageReturnLineFeed [
	terminal feed: 'one', String crlf, 'two'.
	self assert: 'one       ' equals: (terminal rowString: 0).
	self assert: 'two       ' equals: (terminal rowString: 1).
	self assert: 3 @ 1 equals: terminal cursorPos.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testCellAtOutOfRange [
	self assert: nil equals: (terminal cellAt: -1 at: 0).
	self assert: nil equals: (terminal cellAt: 5 at: 0).
	self assert: nil equals: (terminal cellAt: 0 at: 10).
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:08'
}
SWATermTest >> testCellsOfRowMatchCellAt [
	terminal feed: 'a', (self escape: '[1;31;44m'), (String with: (Character value: 16r4E2D)), (self escape: '[38;2;1;2;3m'), (String with: (Character value: 16r2502)), (self escape: '[0m'), 'z'.
	(terminal cellsOfRow: 0) doWithIndex: [ :cell :i |
		self assert: (terminal cellAt: 0 at: i - 1) getHandle equals: cell getHandle ].
	self assert: terminal cols equals: (terminal cellsOfRow: 0) size.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testColours [
	| plain coloured |
	terminal feed: 'a', (self escape: '[31;44m'), 'b'.
	plain := terminal cellAt: 0 at: 0.
	coloured := terminal cellAt: 0 at: 1.
	self assert: coloured fgColor red > 0.5.
	self assert: coloured fgColor blue < 0.1.
	self assert: coloured bgColor blue > 0.5.
	self assert: coloured bgColor red < 0.1.
	self deny: plain fgColor = coloured fgColor.
	self deny: plain bgColor = coloured bgColor.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testControlKey [
	"libvterm's VTermModifier: shift 1, alt 2, ctrl 4."
	terminal keyChar: $c mod: 4.
	self assert: #[3] equals: terminal drainOutput.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testCursorPositionReport [
	terminal feed: (self escape: '[2;3H'), (self escape: '[6n').
	self assert: (self escape: '[2;3R') equals: terminal drainOutput asString.
	self assert: #[] equals: terminal drainOutput.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testCursorPositioning [
	terminal feed: (self escape: '[3;5H'), 'x'.
	self assert: $x equals: (terminal cellAt: 2 at: 4) character.
	self assert: 5 @ 2 equals: terminal cursorPos.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testEraseDisplay [
	terminal feed: 'abc', String crlf, 'def'.
	terminal feed: (self escape: '[2J').
	0 to: terminal rows - 1 do: [ :row |
		self assert: '          ' equals: (terminal rowString: row) ].
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testFeedWritesTextAndMovesCursor [
	terminal feed: 'hello'.
	self assert: 'hello     ' equals: (terminal rowString: 0).
	self assert: 5 @ 0 equals: terminal cursorPos.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testFreeMakesItDead [
	terminal free.
	self assert: terminal isDead.
	self assert: nil equals: (terminal cellAt: 0 at: 0).
	self assert: 0 @ 0 equals: terminal cursorPos.
	self assert: #[] equals: terminal drainOutput.
	self assert: 0 equals: (terminal feed: 'x').
	terminal free.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testKeyEncoding [
	terminal keyChar: $a mod: 0.
	terminal keyCode: terminal keyEnter mod: 0.
	self assert: 'a', String cr equals: terminal drainOutput asString.
	terminal keyCode: terminal keyUp mod: 0.
	self assert: (self escape: '[A') equals: terminal drainOutput asString.
	terminal keyCode: terminal keyBackspace mod: 0.
	self assert: #[127] equals: terminal drainOutput.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testNewTerminalIsBlank [
	self assert: 5 equals: terminal rows.
	self assert: 10 equals: terminal cols.
	self assert: 0 @ 0 equals: terminal cursorPos.
	self assert: '          ' equals: (terminal rowString: 0).
	self assert: 0 equals: (terminal cellAt: 0 at: 0) codepoint.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testResize [
	terminal feed: 'abcdefgh'.
	terminal resizeRows: 3 cols: 4.
	self assert: 3 equals: terminal rows.
	self assert: 4 equals: terminal cols.
	self assert: nil equals: (terminal cellAt: 3 at: 0).
	self assert: nil equals: (terminal cellAt: 0 at: 4).
	self assert: 4 equals: (terminal rowString: 0) size.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:08'
}
SWATermTest >> testRowBytesOfDeadTerminalOrMissingRow [
	self assert: ByteArray new equals: (terminal rowBytes: terminal rows).
	terminal free.
	self assert: ByteArray new equals: (terminal rowBytes: 0).
	self assert: #() equals: (terminal cellsOfRow: 0) asArray.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testRowCodepoints [
	| buffer |
	terminal feed: 'ab'.
	buffer := ByteArray new: terminal cols * 4.
	self assert: 2 equals: (terminal rowCodepointsInto: buffer row: 0).
	self assert: $a asInteger equals: (buffer unsignedLongAt: 1 bigEndian: false).
	self assert: $b asInteger equals: (buffer unsignedLongAt: 5 bigEndian: false).
	self assert: 0 equals: (terminal rowCodepointsInto: buffer row: terminal rows).
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 14:17'
}
SWATermTest >> testScrollbackKeepsLinesScrolledOff [
	| t |
	t := SWATerm rows: 5 cols: 20.
	[ 1 to: 8 do: [ :i | t feed: 'line ', i printString, String crlf ].
	self assert: 4 equals: t scrollbackSize.
	self assert: 'line 1              ' equals:
		(((t cellsIn: (t historyRowBytes: 1)) collect: [ :c | c character ]) as: String) ]
		ensure: [ t free ].
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testScrollsAtBottom [
	1 to: 6 do: [ :i | terminal feed: 'line', i printString, String crlf ].
	self assert: 'line3     ' equals: (terminal rowString: 0).
	self assert: 'line6     ' equals: (terminal rowString: 3).
	self assert: '          ' equals: (terminal rowString: 4).
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testTruecolour [
	| cell |
	terminal feed: (self escape: '[38;2;10;20;30m'), 'x'.
	cell := terminal cellAt: 0 at: 0.
	self assert: 10 equals: (cell fgColor red * 255) rounded.
	self assert: 20 equals: (cell fgColor green * 255) rounded.
	self assert: 30 equals: (cell fgColor blue * 255) rounded.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testUtf8BytesPassThrough [
	terminal feed: (String with: (Character value: 16r2192)) utf8Encoded asString.
	self assert: 16r2192 equals: (terminal cellAt: 0 at: 0) codepoint.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testValidateProcessKeepsALiveTerminal [
	self deny: terminal validateProcess.
	self deny: terminal isDead.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/13/2026 13:37'
}
SWATermTest >> testWheelIsEncodedOnlyInMouseMode [
	| t esc |
	t := SWATerm rows: 10 cols: 40.
	[ esc := String with: (Character value: 27).
	t wheelUp: true row: 2 col: 3 mod: 0.
	self assert: t drainOutput isEmpty.
	t feed: esc, '[?1000h', esc, '[?1006h'.
	t wheelUp: true row: 2 col: 3 mod: 0.
	t wheelUp: false row: 2 col: 3 mod: 0.
	self assert: esc, '[<64;4;3M', esc, '[<65;4;3M' equals: t drainOutput asString ]
		ensure: [ t free ].
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testWideCharacterTakesTwoColumns [
	terminal feed: (String with: (Character value: 16r4E2D)), 'x'.
	self assert: 2 equals: (terminal cellAt: 0 at: 0) width.
	self assert: $x equals: (terminal cellAt: 0 at: 2) character.
	self assert: 3 @ 0 equals: terminal cursorPos.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:57'
}
SWATermTest >> testWideStringIsEncodedAsUtf8 [
	terminal feed: (String with: (Character value: 16r2192)).
	self assert: 16r2192 equals: (terminal cellAt: 0 at: 0) codepoint.
	self assert: 1 equals: terminal cursorPos x.
]
