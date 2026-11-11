"
Times the SWATermMorph refresh path on a detached 120x40 morph. SWATermBenchmark run answers a report.
"
Class {
	#name : #SWATermBenchmark,
	#superclass : #Object,
	#instVars : [
		'rows',
		'cols',
		'morph',
		'results'
	],
	#classInstVars : [
		'lastReport'
	],
	#category : #'SqueakTerminal-Tests',
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark class >> lastReport [
	^ lastReport
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:05'
}
SWATermBenchmark class >> run [
	^ self new run
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark class >> runInBackground [
	"MCP evaluations run at userBackgroundPriority and would starve a run forked there."
	lastReport := nil.
	[ lastReport := [ self run ] on: Error do: [ :e | 'failed: ', e messageText ] ]
		forkAt: Processor systemBackgroundPriority.
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:17'
}
SWATermBenchmark class >> runLatencyInBackground [
	"Spawns a shell, so it is not part of #run. It mostly sleeps, and at a lower
	 priority than the pump it would notice the echo late."
	lastReport := nil.
	[ lastReport := [ self new benchmarkEchoLatency; report ] on: Error do: [ :e | 'failed: ', e messageText ] ]
		forkAt: Processor userBackgroundPriority.
]

{
	#category : #benchmarks,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:16'
}
SWATermBenchmark >> benchmarkEchoLatency [
	"Milliseconds from typing a key until the emulator has the echo
	 (pump), and until the morph has refreshed with it (deferred UI message)."
	| fed drawn |
	fed := OrderedCollection new.
	drawn := OrderedCollection new.
	morph := self newMorph.
	[ morph startCommand: self echoCommand key args: self echoCommand value.
	  self waitUntil: [ morph terminal cursorPos x > 0 ] timeout: 5000.
	  (Delay forMilliseconds: 500) wait.
	  20 timesRepeat: [
		| before start |
		before := morph terminal cursorPos x.
		start := Time utcMicrosecondClock.
		morph terminal keyChar: $x mod: 0.
		morph forwardInput.
		(self waitUntil: [ morph terminal cursorPos x > before ] timeout: 1000)
			ifTrue: [ fed add: (Time utcMicrosecondClock - start) / 1000.0 ].
		(self waitUntil: [ ((morph instVarNamed: 'lastCursorPos') ifNil: [ 0 @ 0 ]) x > before ] timeout: 1000)
			ifTrue: [ drawn add: (Time utcMicrosecondClock - start) / 1000.0 ].
		(Delay forMilliseconds: 30) wait ] ]
		ensure: [ morph stopShell. morph terminal free. morph := nil ].
	self record: 'echo fed to emulator' samples: fed.
	self record: 'echo refreshed' samples: drawn.
]

{
	#category : #benchmarks,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> benchmarkScreens: generator label: label [
	| a b toggle |
	a := self perform: generator with: 0.
	b := self perform: generator with: 1.
	self with: a do: [
		self measure: label, ': read all cells' do: [
			0 to: rows - 1 do: [ :row | morph terminal cellsOfRow: row ] ].
		self measure: label, ': refresh, unchanged' do: [ morph terminalChanged ].
		toggle := false.
		self measure: label, ': feed + refresh, rows changed' do: [
			toggle := toggle not.
			morph feed: (toggle ifTrue: [ b ] ifFalse: [ a ]) ].
		self measure: label, ': full repaint' do: [
			morph gridChanged.
			morph repaintGrid ] ].
]

{
	#category : #benchmarks,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> benchmarkScrolling [
	| chunk |
	chunk := String streamContents: [ :s |
		1 to: rows do: [ :i | s nextPutAll: 'scrolling line ', i printString; nextPutAll: String crlf ] ].
	self with: nil do: [
		self measure: 'scroll 40 lines, 1 refresh' do: [ morph feed: chunk ] ].
]

{
	#category : #benchmarks,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> benchmarkTyping [
	"One keystroke echoed and erased again, as when typing at a prompt."
	self with: (self plainScreen: 0) do: [
		morph feed: (self escape: '[20;10H').
		self measure: 'type + backspace (2 refreshes)' do: [
			morph feed: 'x'.
			morph feed: (String with: Character backspace), ' ', (String with: Character backspace) ] ].
]

{
	#category : #benchmarks,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:15'
}
SWATermBenchmark >> echoCommand [
	^ Smalltalk platformName = 'Win32'
		ifTrue: [ 'cmd.exe' -> #('/q') ]
		ifFalse: [ '/bin/sh' -> #() ]
]

{
	#category : #screens,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> escape: aString [
	^ (String with: Character escape), aString
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:05'
}
SWATermBenchmark >> initialize [
	rows := 40.
	cols := 120.
	results := OrderedDictionary new.
]

{
	#category : #screens,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> line: aString [
	^ (aString, (String new: cols withAll: $ )) first: cols
]

{
	#category : #screens,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> mcScreen: variant [
	"Two blue panels with box-drawing borders and a cyan selection bar at row 5 + variant."
	| bar half |
	bar := (String with: (Character value: 16r2502)).
	half := cols // 2.
	^ String streamContents: [ :s |
		s nextPutAll: (self escape: '[H').
		1 to: rows do: [ :row |
			#(0 1) do: [ :panel |
				s nextPutAll: (self escape: '[44;37m'), bar.
				s nextPutAll: ((row = (5 + variant) and: [ panel = 0 ])
					ifTrue: [ self escape: '[30;46m' ]
					ifFalse: [ self escape: '[44;33m' ]).
				s nextPutAll: (((('file_', row printString, '.txt'), (String new: half withAll: $ )) first: half - 10)).
				s nextPutAll: (self escape: '[44;37m'), bar, '  4096 ' ].
			s nextPutAll: (self escape: '[0m').
			row < rows ifTrue: [ s nextPutAll: String crlf ] ] ]
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> measure: label do: aBlock [
	"Repeats aBlock for at least 300 ms and records milliseconds per run."
	| n start elapsed |
	aBlock value.
	n := 0.
	start := Time millisecondClockValue.
	[ aBlock value.
	  n := n + 1.
	  (elapsed := Time millisecondsSince: start) < 300 ] whileTrue.
	results at: label put: elapsed / n.
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> newMorph [
	| m |
	m := SWATermMorph new.
	m extent: (cols * (m font widthOf: $m)) @ (rows * m font height).
	(m terminal rows = rows and: [ m terminal cols = cols ])
		ifFalse: [ self error: 'grid is not ', cols printString, 'x', rows printString ].
	^ m
]

{
	#category : #screens,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> plainScreen: variant [
	^ String streamContents: [ :s |
		s nextPutAll: (self escape: '[H').
		1 to: rows do: [ :row |
			s nextPutAll: (self line: '-rw-r--r-- 1 jens jens ', (row * 1000 + variant) printString, ' Nov 11 12:00 file_', row printString, '.txt').
			row < rows ifTrue: [ s nextPutAll: String crlf ] ] ]
]

{
	#category : #screens,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> rainbowScreen: variant [
	"A colour per cell, as in opencode's voice orb: 16 foregrounds, 16 backgrounds."
	| block |
	block := String with: (Character value: 16r2580).
	^ String streamContents: [ :s |
		s nextPutAll: (self escape: '[H').
		1 to: rows do: [ :row |
			1 to: cols do: [ :col |
				s nextPutAll: (self escape: '[38;5;', (16 + (row + col + variant \\ 16)) printString, ';48;5;', (232 + (col \\ 16)) printString, 'm').
				s nextPutAll: block ].
			s nextPutAll: (self escape: '[0m').
			row < rows ifTrue: [ s nextPutAll: String crlf ] ] ]
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:15'
}
SWATermBenchmark >> record: label samples: samples [
	samples isEmpty ifTrue: [ ^ results at: label, ': no samples' put: Float nan ].
	results at: label, ', median' put: (samples asSortedCollection asArray at: samples size + 1 // 2).
	results at: label, ', max' put: samples max.
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:11'
}
SWATermBenchmark >> report [
	^ String streamContents: [ :s |
		results keysAndValuesDo: [ :label :ms |
			s nextPutAll: (label padded: #right to: 36 with: $ ).
			s nextPutAll: ((ms asFloat printShowingDecimalPlaces: 2) padded: #left to: 9 with: $ ).
			s nextPutAll: ' ms'; cr ] ]
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:05'
}
SWATermBenchmark >> results [
	^ results
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:05'
}
SWATermBenchmark >> run [
	self benchmarkScreens: #plainScreen: label: 'plain'.
	self benchmarkScreens: #mcScreen: label: 'mc'.
	self benchmarkScreens: #rainbowScreen: label: 'rainbow'.
	self benchmarkTyping.
	self benchmarkScrolling.
	^ self report
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:15'
}
SWATermBenchmark >> waitUntil: aBlock timeout: milliseconds [
	| deadline |
	deadline := Time millisecondClockValue + milliseconds.
	[ aBlock value ] whileFalse: [
		Time millisecondClockValue > deadline ifTrue: [ ^ false ].
		(Delay forMilliseconds: 1) wait ].
	^ true
]

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/11/2026 11:06'
}
SWATermBenchmark >> with: screenOrNil do: aBlock [
	morph := self newMorph.
	[ screenOrNil ifNotNil: [ morph feed: screenOrNil ].
	  morph imageForm.
	  aBlock value ] ensure: [ morph terminal free. morph := nil ].
]
