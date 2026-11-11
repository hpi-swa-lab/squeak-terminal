Class {
	#name : #SWATermMorphTest,
	#superclass : #TestCase,
	#instVars : [
		'morph'
	],
	#category : #'SqueakTerminal-Tests'
}

{
	#category : #support,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> colorOfCellAtRow: row col: col [
	^ morph imageForm colorAt: (col * (morph font widthOf: $m)) + 1 @ (row * morph font height + 1)
]

{
	#category : #support,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> escape: aString [
	^ (String with: Character escape), aString
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> setUp [
	morph := SWATermMorph new.
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> tearDown [
	morph terminal free.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> testColourOnlyChangeRepaintsRow [
	"mc moves its selection bar this way: the same text, other colours."
	morph feed: 'abc', (self escape: '[6;1H').
	morph imageForm.
	morph feed: (self escape: '[1;1H'), (self escape: '[41m'), 'abc', (self escape: '[0m'), (self escape: '[6;1H').
	self assert: ((self colorOfCellAtRow: 0 col: 0) red > 0.5).
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:18'
}
SWATermMorphTest >> testPumpPollsFastOnlyAfterInput [
	self assert: 16 equals: morph idlePollInterval.
	morph instVarNamed: 'lastInputTime' put: Time millisecondClockValue.
	self assert: 1 equals: morph idlePollInterval.
	morph instVarNamed: 'lastInputTime' put: Time millisecondClockValue - 1000.
	self assert: 16 equals: morph idlePollInterval.
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:11'
}
SWATermMorphTest >> testRepaintMatchesCellByCellDrawing [
	"Background runs must give the same pixels as filling each cell."
	| expected canvas |
	morph feed: 'plain ', (self escape: '[44;37m'), 'blue bar  ', (self escape: '[30;46m'), 'cyan', (self escape: '[0m'), ' ', (self escape: '[7m'), 'rev', (self escape: '[0m'), String crlf, (self escape: '[41m'), (self escape: '[K'), 'red row'.
	morph imageForm.
	expected := Form extent: morph extent depth: 32.
	expected fillColor: Color black.
	canvas := expected getCanvas.
	0 to: morph terminal rows - 1 do: [ :row |
		0 to: morph terminal cols - 1 do: [ :col |
			morph drawCell: (morph terminal cellAt: row at: col) row: row col: col origin: 0 @ 0 on: canvas ] ].
	self assert: (expected bits = (morph instVarNamed: 'gridForm') bits).
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:12'
}
SWATermMorphTest >> testRightHalfOfWideCharacterDrawsNothing [
	| form |
	morph feed: (String with: (Character value: 16r4E2D)).
	form := Form extent: 40 @ 40 depth: 32.
	form fillColor: Color black.
	morph drawGlyphOf: (morph terminal cellAt: 0 at: 1) color: Color white at: 0 @ 0 on: form getCanvas.
	self assert: ((0 to: 39) allSatisfy: [ :x | (0 to: 39) allSatisfy: [ :y | (form colorAt: x @ y) = Color black ] ]).
]

{
	#category : #tests,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> testTextChangeRepaintsRow [
	morph feed: 'abc', (self escape: '[6;1H').
	morph imageForm.
	morph feed: (self escape: '[1;1H'), (self escape: '[41m'), 'xyz', (self escape: '[0m'), (self escape: '[6;1H').
	self assert: ((self colorOfCellAtRow: 0 col: 0) red > 0.5).
]
