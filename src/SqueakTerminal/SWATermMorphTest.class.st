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
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 10:56'
}
SWATermMorphTest >> testTextChangeRepaintsRow [
	morph feed: 'abc', (self escape: '[6;1H').
	morph imageForm.
	morph feed: (self escape: '[1;1H'), (self escape: '[41m'), 'xyz', (self escape: '[0m'), (self escape: '[6;1H').
	self assert: ((self colorOfCellAtRow: 0 col: 0) red > 0.5).
]
