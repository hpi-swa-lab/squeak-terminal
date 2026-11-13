"
Scenarios for TTCFont glyph caching, measured in microseconds. Each scenario renders with a private TTCFont on an installed description, so it starts with empty caches and leaves the fonts of the UI alone; only the global GlyphCacheData ring is shared.
"
Class {
	#name : #TTCFontRenderBenchmark,
	#superclass : #Object,
	#category : #'SqueakTerminal-Benchmarks',
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #running,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark class >> run: aBlock logTo: fileName [
	"Run aBlock in the background, below the MCP server and the UI; aBlock gets a one-argument
	 block that appends a line to /tmp/opencode/fontbench/fileName."
	| path |
	(FileDirectory on: '/tmp/opencode/fontbench') assureExistence.
	path := '/tmp/opencode/fontbench/', fileName.
	FileStream forceNewFileNamed: path do: [ :f | f nextPutAll: '# ', DateAndTime now printString; lf ].
	^ [ | log |
		log := [ :line | FileStream fileNamed: path do: [ :f | f setToEnd; nextPutAll: line; lf ] ].
		[ aBlock value: log. log value: '# done' ]
			on: Error do: [ :e | log value: '# ERROR ', e messageText, ' in ', e signalerContext printString ] ]
		forkAt: Processor systemBackgroundPriority
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:26'
}
TTCFontRenderBenchmark >> animatedOrb: aFont frames: frameCount colours: colourCount [
	"Each frame draws colourCount half blocks, every one in a colour never seen before. Answer milliseconds per frame."
	| canvas rnd block |
	canvas := self canvas.
	rnd := Random seed: 11.
	block := WideString with: (Character value: 16r2580).
	^ (1 to: frameCount) collect: [ :i |
		Time millisecondsToRun: [
			colourCount timesRepeat: [
				canvas drawString: block at: 0 @ 0 font: aFont color: (Color r: rnd next g: rnd next b: rnd next) ] ] ]
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:26'
}
TTCFontRenderBenchmark >> animatedOrbPrototype: aFont frames: frameCount colours: colourCount [
	"As animatedOrb:frames:colours:, through the colour-free coverage glyphs of the prototype."
	| form rnd block glyphs maps |
	form := Form extent: 3000 @ 64 depth: 32.
	rnd := Random seed: 11.
	block := WideString with: (Character value: 16r2580).
	glyphs := Array new: 16r30000.
	maps := Dictionary new.
	^ (1 to: frameCount) collect: [ :i |
		Time millisecondsToRun: [
			colourCount timesRepeat: [
				self prototypeDraw: block at: 0 @ 0 font: aFont colour: (Color r: rnd next g: rnd next b: rnd next) on: form glyphs: glyphs maps: maps ] ] ]
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> asciiText [
	^ 'The quick brown fox jumps over the lazy dog. 0123456789 (){}[]<>+-*/=!?'
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> blockText [
	^ WideString withAll: ((16r2580 to: 16r259F) collect: [ :cp | Character value: cp ])
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> canvas [
	^ (Form extent: 3000 @ 64 depth: 32) getCanvas
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:25'
}
TTCFontRenderBenchmark >> colourChurn: familyName class: aFontClass text: aString colours: count [
	"Draw aString once in each of count new colours, then once more in the same colours.
	 Answer microseconds per colour for both passes, the colour cache slots, the GC work
	 during the first pass (full GCs, ms, scavenges, ms), and the milliseconds of a full GC
	 with and without those caches."
	| font canvas colours cold warm slots gc0 gc1 gcWith gcWithout |
	font := self privateFont: familyName class: aFontClass.
	canvas := self canvas.
	colours := self colours: count.
	Smalltalk garbageCollect.
	gc0 := self gcCounters.
	cold := Time microsecondsToRun: [ colours do: [ :c | canvas drawString: aString at: 0 @ 0 font: font color: c ] ].
	gc1 := self gcCounters.
	warm := Time microsecondsToRun: [ colours do: [ :c | canvas drawString: aString at: 0 @ 0 font: font color: c ] ].
	slots := (font instVarNamed: 'colorToCacheMap') inject: 0 into: [ :sum :each | sum + each size ].
	gcWith := Time millisecondsToRun: [ Smalltalk garbageCollect ].
	font flushCache.
	gcWithout := Time millisecondsToRun: [ Smalltalk garbageCollect ].
	^ { cold / count asFloat. warm / count asFloat. slots. gc1 - gc0. gcWith. gcWithout }
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:25'
}
TTCFontRenderBenchmark >> colourChurn: familyName text: aString colours: count [
	^ self colourChurn: familyName class: TTCFont text: aString colours: count
]

{
	#category : #experiments,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:24'
}
TTCFontRenderBenchmark >> colourMapFor: aColor [
	"Coverage 0..255 to the premultiplied 32-bit pixel rule 34 expects."
	| map r g b a |
	map := Bitmap new: 256.
	r := (aColor red * 255) rounded.
	g := (aColor green * 255) rounded.
	b := (aColor blue * 255) rounded.
	a := (aColor alpha * 255) rounded.
	0 to: 255 do: [ :i |
		map at: i + 1 put:
			((a * i + 127 // 255) bitShift: 24)
			+ ((r * i + 127 // 255) bitShift: 16)
			+ ((g * i + 127 // 255) bitShift: 8)
			+ (b * i + 127 // 255) ].
	^ map
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> colourSwitch: familyName text: aString [
	"Microseconds per glyph, all cached, drawing glyph by glyph in one colour versus two alternating colours."
	| font canvas one two |
	font := self privateFont: familyName.
	canvas := self canvas.
	aString do: [ :ch |
		canvas drawString: (String with: ch) at: 0 @ 0 font: font color: Color white.
		canvas drawString: (String with: ch) at: 0 @ 0 font: font color: Color red ].
	one := self median: [ aString do: [ :ch | canvas drawString: (String with: ch) at: 0 @ 0 font: font color: Color white ] ].
	two := self median: [ aString doWithIndex: [ :ch :i | canvas drawString: (String with: ch) at: 0 @ 0 font: font color: (i odd ifTrue: [ Color white ] ifFalse: [ Color red ]) ] ].
	^ { one / aString size asFloat. two / aString size asFloat }
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> colours: count [
	^ (1 to: count) collect: [ :i | Color r: i / count g: 0.5 b: 1 - (i / count) ]
]

{
	#category : #experiments,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:24'
}
TTCFontRenderBenchmark >> coverageGlyph: aCharacter font: aFont [
	"The glyph's alpha channel as an 8-bit Form: the same for every colour."
	| form coverage |
	aFont foregroundColor: Color white.
	form := (aFont glyphInfoOf: aCharacter into: (Array new: 5)) first.
	coverage := Form extent: form extent depth: 8.
	(BitBlt toForm: coverage)
		sourceForm: form;
		colorMap: (ColorMap shifts: #(-24 0 0 0) masks: #(16rFF000000 0 0 0));
		combinationRule: Form over;
		sourceRect: form boundingBox;
		destOrigin: 0 @ 0;
		copyBits.
	coverage offset: form offset.
	^ coverage -> form advanceWidth
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:21'
}
TTCFontRenderBenchmark >> firstSpanNamed: aString in: aNode [
	aNode children do: [ :span |
		span name = aString ifTrue: [ ^ span ].
		(self firstSpanNamed: aString in: span) ifNotNil: [ :found | ^ found ] ].
	^ nil
]

{
	#category : #measuring,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:20'
}
TTCFontRenderBenchmark >> gcCounters [
	"Full GCs, their milliseconds, scavenges, their milliseconds."
	^ #(7 8 9 10) collect: [ :i | Smalltalk vmParameterAt: i ]
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> latin1Glyphs: count [
	^ String withAll: (((33 to: 126) , (161 to: 255) first: count) collect: [ :cp | Character value: cp ])
]

{
	#category : #measuring,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> median: aBlock [
	| times |
	times := (1 to: 5) collect: [ :i | Time microsecondsToRun: aBlock ].
	^ (times asSortedCollection asArray at: 3)
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> missCosts: familyName text: aString [
	"Per glyph: fetching the outline, fetching plus rasterising, and allocating one colour cache."
	| font desc codes fetch raster alloc |
	font := self privateFont: familyName.
	desc := font ttcDescription.
	codes := (aString asSet collect: [ :ch | ch asInteger ]) asArray.
	font foregroundColor: Color white.
	fetch := self median: [ codes do: [ :cp | desc at: cp ] ].
	raster := self median: [ codes do: [ :cp | font computeForm: cp ] ].
	alloc := self median: [ font createCache ].
	^ { fetch / codes size asFloat. raster / codes size asFloat. alloc. font maxCodePoint + 1 }
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:26'
}
TTCFontRenderBenchmark >> orbCapture: aFont frames: count [
	"The 80x24 opencode orb capture drawn count times through SWATermMorph>>drawCell:row:col:origin:on:. Answer milliseconds per frame."
	| test cells canvas times |
	test := SWATermRenderPerformanceTest new.
	test setUp.
	^ [ (test instVarNamed: 'morph') font: aFont.
		cells := test captureCells.
		canvas := (Form extent: (80 * (aFont widthOf: $m)) @ (24 * aFont height) depth: 32) getCanvas.
		times := (1 to: count) collect: [ :i | Time millisecondsToRun: [ test render: cells on: canvas ] ].
		times ] ensure: [ test tearDown ]
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> pointSize [
	^ 14
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:21'
}
TTCFontRenderBenchmark >> printSpan: span depth: depth limit: limit on: log [
	log value: (String new: depth * 2 withAll: $ ), span durationMicros printString, 'us ', span name.
	depth < limit ifTrue: [
		span children do: [ :child | self printSpan: child depth: depth + 1 limit: limit on: log ] ]
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:25'
}
TTCFontRenderBenchmark >> privateFont: familyName [
	^ self privateFont: familyName class: TTCFont
]

{
	#category : #fixtures,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:25'
}
TTCFontRenderBenchmark >> privateFont: familyName class: aFontClass [
	| font |
	font := aFontClass new initialize: (TextStyle named: familyName) defaultFont.
	font setPointSize: self pointSize.
	^ font
]

{
	#category : #experiments,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:24'
}
TTCFontRenderBenchmark >> prototypeCheck: familyName text: aString colours: count [
	"Largest per-channel difference (0..255) between drawString: and the prototype, over count colours on black."
	| font a b glyphs maps worst |
	font := self privateFont: familyName.
	glyphs := Array new: 16r30000.
	maps := Dictionary new.
	worst := 0.
	(self colours: count) do: [ :c |
		a := Form extent: 1400 @ 40 depth: 32.
		b := Form extent: 1400 @ 40 depth: 32.
		a fillColor: Color black.
		b fillColor: Color black.
		a getCanvas drawString: aString at: 0 @ 0 font: font color: c.
		self prototypeDraw: aString at: 0 @ 0 font: font colour: c on: b glyphs: glyphs maps: maps.
		1 to: a bits size do: [ :i | | pa pb |
			pa := a bits at: i.
			pb := b bits at: i.
			pa = pb ifFalse: [
				0 to: 24 by: 8 do: [ :shift |
					worst := worst max: (((pa bitShift: shift negated) bitAnd: 255) - ((pb bitShift: shift negated) bitAnd: 255)) abs ] ] ] ].
	^ worst
]

{
	#category : #experiments,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:24'
}
TTCFontRenderBenchmark >> prototypeDraw: aString at: aPoint font: aFont colour: aColor on: aForm glyphs: glyphCache maps: mapCache [
	"glyphCache is an Array indexed by codepoint + 1 holding {coverage form. advance}."
	| blt destX destY |
	blt := BitBlt toForm: aForm.
	blt colorMap: (mapCache at: aColor ifAbsentPut: [ self colourMapFor: aColor ]);
		combinationRule: Form blendAlphaScaled;
		sourceX: 0; sourceY: 0.
	destX := aPoint x.
	destY := aPoint y.
	aString do: [ :ch | | code entry glyph |
		code := ch asInteger + 1.
		entry := glyphCache at: code.
		entry ifNil: [
			entry := self coverageGlyph: ch font: aFont.
			entry := { entry key. entry value }.
			glyphCache at: code put: entry ].
		glyph := entry at: 1.
		blt sourceForm: glyph;
			destX: destX + glyph offset x;
			destY: destY + glyph offset y;
			width: glyph width;
			height: glyph height;
			copyBits.
		destX := destX + (entry at: 2) ].
	^ destX @ destY
]

{
	#category : #experiments,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:24'
}
TTCFontRenderBenchmark >> prototypeTimings: familyName text: aString colours: count [
	"Microseconds per glyph, warm, for drawString: and the prototype; then microseconds per new colour for both."
	| font form canvas glyphs maps colours warmOld warmNew churnOld churnNew |
	font := self privateFont: familyName.
	form := Form extent: 3000 @ 64 depth: 32.
	canvas := form getCanvas.
	glyphs := Array new: 16r30000.
	maps := Dictionary new.
	canvas drawString: aString at: 0 @ 0 font: font color: Color white.
	self prototypeDraw: aString at: 0 @ 0 font: font colour: Color white on: form glyphs: glyphs maps: maps.
	warmOld := (self median: [ 20 timesRepeat: [ canvas drawString: aString at: 0 @ 0 font: font color: Color white ] ]) / (20 * aString size) asFloat.
	warmNew := (self median: [ 20 timesRepeat: [ self prototypeDraw: aString at: 0 @ 0 font: font colour: Color white on: form glyphs: glyphs maps: maps ] ]) / (20 * aString size) asFloat.
	colours := self colours: count.
	churnNew := (Time microsecondsToRun: [ colours do: [ :c | self prototypeDraw: aString at: 0 @ 0 font: font colour: c on: form glyphs: glyphs maps: maps ] ]) / count asFloat.
	Smalltalk garbageCollect.
	churnOld := (Time microsecondsToRun: [ colours do: [ :c | canvas drawString: aString at: 0 @ 0 font: font color: c ] ]) / count asFloat.
	font flushCache.
	^ { warmOld. warmNew. churnOld. churnNew }
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> ringFrames: familyName glyphs: glyphCount colours: colourCount frames: frameCount collect: aSymbol [
	"Draw the same frame frameCount times: glyphCount glyphs in each of colourCount colours.
	 Before each frame collect garbage: #none, #scavenge or #full. Answer microseconds per frame."
	| font canvas text colours |
	font := self privateFont: familyName.
	canvas := self canvas.
	text := self latin1Glyphs: glyphCount.
	colours := self colours: colourCount.
	^ (1 to: frameCount) collect: [ :i |
		aSymbol == #scavenge ifTrue: [ Smalltalk garbageCollectMost ].
		aSymbol == #full ifTrue: [ Smalltalk garbageCollect ].
		Time microsecondsToRun: [ colours do: [ :c | canvas drawString: text at: 0 @ 0 font: font color: c ] ] ]
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:22'
}
TTCFontRenderBenchmark >> spy: aBlock seconds: seconds rate: hz on: log [
	"Sample this VM with st-spy while aBlock runs repeatedly for seconds, then log where the time went."
	| spy deadline |
	spy := SWASamplingTally new.
	spy duration: seconds + 2; rate: hz; showProgress: false.
	spy record.
	spy failed ifTrue: [ ^ log value: 'st-spy did not start: ', spy failureReason printString ].
	(Delay forSeconds: 1) wait.
	deadline := Time millisecondClockValue + (seconds * 1000).
	[ Time millisecondClockValue < deadline ] whileTrue: [ aBlock value ].
	deadline := Time millisecondClockValue + 60000.
	[ spy isReady or: [ spy failed or: [ Time millisecondClockValue > deadline ] ] ]
		whileFalse: [ (Delay forMilliseconds: 250) wait ].
	spy isReady ifFalse: [ ^ log value: 'no trace: ', spy failureReason printString ].
	spy buildTree.
	log value: 'trace file ', spy outputFile.
	self summariseSamples: spy rootNode on: log top: 40
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:21'
}
TTCFontRenderBenchmark >> summariseLane: lane on: log top: count [
	"Self and inclusive microseconds per method over every span in lane, largest self time first."
	| stats walk rows |
	stats := Dictionary new.
	walk := nil.
	walk := [ :node |
		node children do: [ :span | | entry |
			entry := stats at: span name ifAbsentPut: [ Array new: 3 withAll: 0 ].
			entry at: 1 put: (entry at: 1) + 1.
			entry at: 2 put: (entry at: 2) + span selfMicros.
			entry at: 3 put: (entry at: 3) + span durationMicros.
			walk value: span ] ].
	walk value: lane.
	rows := stats associations asSortedCollection: [ :a :b | (a value at: 2) >= (b value at: 2) ].
	log value: 'calls / self us / incl us (inclusive double-counts recursion)'.
	(rows asArray first: (count min: rows size)) do: [ :a |
		log value: ((a value at: 1) printString padded: #left to: 7 with: $ ), ' ',
			((a value at: 2) printString padded: #left to: 9 with: $ ), ' ',
			((a value at: 3) printString padded: #left to: 9 with: $ ), '  ', a key ]
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:22'
}
TTCFontRenderBenchmark >> summariseSamples: root on: log top: count [
	"Self and inclusive milliseconds per frame name over the whole sampled tree. Inclusive
	 time counts a frame once per path, so recursion does not inflate it."
	| selfTimes totalTimes walk total |
	selfTimes := Dictionary new.
	totalTimes := Dictionary new.
	walk := nil.
	walk := [ :node :onPath |
		node children do: [ :child | | path |
			selfTimes at: child name put: (selfTimes at: child name ifAbsent: [ 0 ]) + child selfSize.
			(onPath includes: child name) ifFalse: [
				totalTimes at: child name put: (totalTimes at: child name ifAbsent: [ 0 ]) + child totalSize ].
			path := onPath copyWith: child name.
			walk value: child value: path ] ].
	walk value: root value: #().
	total := root totalSize max: 1.
	log value: 'sampled ', (total // 1000) printString, ' ms'.
	log value: '--- by self time: ms, % of sampled'.
	((selfTimes associations asSortedCollection: [ :a :b | a value >= b value ]) asArray first: (count min: selfTimes size))
		do: [ :a | log value: ((a value // 1000) printString padded: #left to: 7 with: $ ), ((a value * 100 // total) printString padded: #left to: 4 with: $ ), '%  ', a key ].
	log value: '--- by inclusive time: ms, % of sampled'.
	((totalTimes associations asSortedCollection: [ :a :b | a value >= b value ]) asArray first: (count min: totalTimes size))
		do: [ :a | log value: ((a value // 1000) printString padded: #left to: 7 with: $ ), ((a value * 100 // total) printString padded: #left to: 4 with: $ ), '%  ', a key ]
]

{
	#category : #tracing,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:21'
}
TTCFontRenderBenchmark >> trace: aBlock packages: globs on: log [
	"Run aBlock under SWATraceWrapper on globs, in this process, and log what it did."
	| cov me root lane miss |
	me := Processor activeProcess.
	SWAMethodWrapper uninstallAllStrayWrappers.
	cov := SWACoverage new.
	cov captureCallTree: false; evictAt: nil; methodsForPackages: globs.
	cov instrumentTrace.
	[ aBlock value ] ensure: [
		[ cov collectTrace. cov uninstall ] ensure: [
			SWAMethodWrapper uninstallAllStrayWrappers.
			SWATallyWrapper resetCallTree.
			SWATimingWrapper resetFrames.
			SWATraceWrapper resetTrace ] ].
	log value: cov traceStatus.
	root := cov collectTraceRoot.
	root ifNil: [ ^ self ].
	lane := root children detect: [ :each | each process == me ] ifNone: [ ^ log value: 'no lane for this process' ].
	self summariseLane: lane on: log top: 30.
	miss := self firstSpanNamed: 'TTCFont>>computeForm:' in: lane.
	miss ifNotNil: [
		log value: 'one glyph miss:'.
		self printSpan: miss depth: 0 limit: 4 on: log ]
]

{
	#category : #scenarios,
	#'squeak_changestamp' : 'MCPServer (jl) 11/10/2026 10:19'
}
TTCFontRenderBenchmark >> warmHit: familyName text: aString [
	"Microseconds per glyph once every glyph is cached: one font, one colour."
	| font canvas |
	font := self privateFont: familyName.
	canvas := self canvas.
	canvas drawString: aString at: 0 @ 0 font: font color: Color white.
	^ (self median: [ 20 timesRepeat: [ canvas drawString: aString at: 0 @ 0 font: font color: Color white ] ])
		/ (20 * aString size) asFloat
]
