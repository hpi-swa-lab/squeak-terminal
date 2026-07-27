Class {
	#name : #SWATermMorph,
	#superclass : #Morph,
	#instVars : [
		'terminal',
		'font',
		'cellWidth',
		'cellHeight',
		'defaultFg',
		'defaultBg',
		'pty',
		'pumpProcess',
		'blinkState',
		'selectionStart',
		'selectionEnd',
		'selecting'
	],
	#classVars : [
		'DebugEvents'
	],
	#category : #SqueakTerminal
}

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:51'
}
SWATermMorph class >> availableFontFamilies [
	"Sorted names of TrueType (TTCFont) families currently loaded in the image.
	 These are the fixed-width-capable families the chooser offers. Names are the
	 registered TextStyle keys (spaces stripped), accepted by TTCFont familyName:."
	^ (TextStyle actualTextStyles associations
		select: [ :a |
			a value fontArray notNil
				and: [ a value fontArray notEmpty ]
				and: [ (a value fontArray first class name beginsWith: 'TTC') ] ]
		thenCollect: [ :a | a key asString ])
		asSortedCollection asArray
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:33'
}
SWATermMorph class >> checkFontOnInstall [
	"Run at package-install time (from #initialize). Do NOT block the load with a
	 modal dialog or a 26 MB download here -- headless loads must succeed. Just
	 report status. The actual download-if-missing (with a user confirm) happens
	 lazily the first time a terminal is opened, via #defaultFont."
	| dir |
	(TextStyle named: self fontFamilyName) ifNotNil: [ ^ self ].
	dir := self fontDirectory.
	(self fontFileNames allSatisfy: [ :f | dir fileExists: f ])
		ifTrue: [ self logLine: 'faces present, will install on first terminal open' ]
		ifFalse: [ self logLine: 'font "', self fontFamilyName,
			'" not installed; you will be asked to download it when you open a terminal' ]
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:50'
}
SWATermMorph class >> confirmAndDownloadFontInto: dir [
	"The terminal font faces are missing. Ask the user for permission to download
	 them from the Nerd Fonts GitHub release, then fetch + extract.
	 Answer true on success, false if the user declines or it fails."
	(self confirm: ('The terminal font "{1}" is not installed.
Download it now from the Nerd Fonts release?
({2})' format: { self fontFamilyName. self fontDownloadUrl }))
		ifFalse: [ self logLine: 'download declined by user'. ^ false ].
	^ [ self downloadAndExtractFontInto: dir ]
		on: Error
		do: [ :e | self logLine: 'download failed: ', e messageText. false ]
]

{
	#category : #preferences,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:35'
}
SWATermMorph class >> debugEvents [
	"When on, SWATermMorph prints keyboard/mouse event routing to the
	 Transcript. Toggleable from the Preferences panel (category SqueakTerminal)."
	<preference: 'Debug terminal input events to Transcript' category: 'SqueakTerminal' description: 'Print keyboard and mouse event routing for SWATermMorph to the Transcript (for diagnosing input handling)' type: #Boolean>
	^ DebugEvents ifNil: [false]
]

{
	#category : #preferences,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:06'
}
SWATermMorph class >> debugEvents: aBoolean [
	DebugEvents := aBoolean
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:10'
}
SWATermMorph class >> defaultFont [
	"The preferred terminal font: Cascadia Mono Nerd Font (braille spinners,
	 box-drawing/block progress bars, Nerd icons/powerline), downloaded on first
	 use if absent. Falls back to the system fixed font if it can't be installed."
	| name |
	name := self ensureDefaultFontInstalled.
	name ifNil: [ ^ TextStyle defaultFixedFont ].
	^ TTCFont familyName: name pointSize: self defaultFontSize
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:10'
}
SWATermMorph class >> defaultFontSize [
	"Point size a new terminal opens at (and the target of Ctrl+0 / reset font)."
	^ 14
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:32'
}
SWATermMorph class >> downloadAndExtractFontInto: dir [
	"Download the Nerd Font release zip with curl and extract just the faces in
	 #fontFileNames into dir. Answer true if all wanted faces end up present.
	 Uses curl (handles the GitHub release redirect + HTTPS) rather than the
	 image's HTTP stack. Raises on hard failure; caller decides how to report."
	| zipPath want archive |
	dir assureExistence.
	zipPath := (dir fullNameFor: 'nerdfont-download.zip').
	self logLine: 'Downloading ', self fontDownloadUrl, ' ...'.
	UnixProcess waitForCommand:
		'curl -fsSL ', self fontDownloadUrl, ' -o ', zipPath.
	(FileDirectory default fileExists: zipPath) ifFalse: [
		^ self error: 'curl produced no file' ].
	want := self fontFileNames asSet.
	archive := ZipArchive new readFrom: zipPath.
	[ archive members do: [ :m |
		| base |
		base := m fileName copyAfterLast: $/.
		base isEmpty ifTrue: [ base := m fileName ].
		(want includes: base) ifTrue: [
			| out |
			out := dir fullNameFor: base.
			self logLine: 'Extracting ', base.
			(FileStream forceNewFileNamed: out) binary
				nextPutAll: m contents; close ] ]
	] ensure: [ archive close ].
	FileDirectory default deleteFileNamed: zipPath ifAbsent: [].
	^ self fontFileNames allSatisfy: [ :n | dir fileExists: n ]
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:32'
}
SWATermMorph class >> ensureDefaultFontInstalled [
	"Make the terminal font (#fontFamilyName) available, downloading it first if
	 the .ttf files are missing. Idempotent. Returns the family name on success,
	 or nil so #defaultFont can fall back to the system fixed font.

	 1. Already installed in the image?      -> done.
	 2. Face files present in fontDirectory? -> install them.
	 3. Missing?                             -> ask the user, download, install."
	| name dir |
	name := self fontFamilyName.
	(TextStyle named: name) ifNotNil: [ ^ name ].
	dir := self fontDirectory.
	^ [
		(self fontFileNames allSatisfy: [ :f | dir fileExists: f ])
			ifFalse: [ (self confirmAndDownloadFontInto: dir) ifFalse: [ ^ nil ] ].
		self installFontFilesFrom: dir
	] on: Error do: [ :e |
		self logLine: 'install failed: ', e messageText. nil ]
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:10'
}
SWATermMorph class >> fontDirectory [
	"Directory holding the bundled terminal .ttf files (ships with the repo).
	 Resolved relative to the running image's directory so it works wherever
	 the repo lives -- no hardcoded absolute path."
	^ (FileDirectory on: Smalltalk imagePath) / 'fonts'
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:50'
}
SWATermMorph class >> fontDownloadUrl [
	"The Nerd Fonts release zip that contains our faces. Latest release."
	^ 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.zip'
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:50'
}
SWATermMorph class >> fontFamilyName [
	"The family name libvterm cells are rendered with. Cascadia Mono (the
	 Windows Terminal font, Nerd-Font-patched) has full braille (spinners),
	 block/box-drawing (progress bars) and Nerd icon/powerline glyphs, with a
	 comfortable width -- the combination DejaVu Sans Mono lacked.
	 Note: this is the name Squeak registers the TTF under (spaces stripped),
	 which is what TTCFont familyName: and TextStyle named: expect."
	^ 'CaskaydiaMonoNFM'
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:50'
}
SWATermMorph class >> fontFileNames [
	"The .ttf faces we need present in fontDirectory (Regular + Bold)."
	^ #('CaskaydiaMonoNerdFontMono-Regular.ttf' 'CaskaydiaMonoNerdFontMono-Bold.ttf')
]

{
	#category : #'class initialization',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:33'
}
SWATermMorph class >> initialize [
	"Register the 'Terminal' entry in the world's Apps menu. Idempotent:
	 removes any prior entry for this receiver first."
	"Revive open terminals after a snapshot: re-run their remembered shell
	 instead of leaving them dead. Runs after SWATerm/SWATermPty in the list."
	Smalltalk addToStartUpList: self.
	self checkFontOnInstall.
	(TheWorldMenu respondsTo: #registerOpenCommand:) ifFalse: [ ^ self ].
	TheWorldMenu unregisterOpenCommandWithReceiver: self.
	TheWorldMenu registerOpenCommand: {
		'Terminal'.
		{ self. #open } }
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:32'
}
SWATermMorph class >> installFontFilesFrom: dir [
	"Install our #fontFileNames from dir into the image as TTCFonts.
	 Answer the family name, or nil if nothing installed."
	| files |
	files := self fontFileNames
		select: [ :f | dir fileExists: f ]
		thenCollect: [ :f | dir fullNameFor: f ].
	files isEmpty ifTrue: [ ^ nil ].
	^ (TTCFont installFromFileNames: files)
		ifEmpty: [ nil ]
		ifNotEmpty: [ self fontFamilyName ]
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:32'
}
SWATermMorph class >> logLine: aString [
	"Progress line to the Transcript during font install/download."
	Transcript showln: 'SWATerm font: ', aString
]

{
	#category : #'instance creation',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:34'
}
SWATermMorph class >> open [
	"Open a terminal in a SystemWindow and start a bash shell."
	| m |
	m := SWATermMorph new.
	m openInWindow.
	m startShell.
	^ m
]

{
	#category : #'class initialization',
	#'squeak_changestamp' : 'MCPServer 7/24/2026 14:46'
}
SWATermMorph class >> startUp: resuming [
	"On a fresh image load (resuming = true) every terminal morph's libvterm
	 handles and PTY are dead (SWATerm/SWATermPty startUp: already ran beDead on
	 them -- they precede us in the startUp list). Rather than leave dead
	 terminals on screen, revive each one: rebuild the emulator and re-run the
	 shell/command it remembered. resuming = false is a same-process continue --
	 the live terminals are fine, leave them alone."
	resuming ifFalse: [ ^ self ].
	self allInstancesDo: [ :m |
		[ m reviveAfterSnapshot ] on: Error do: [ :e |
			Transcript showln: 'SWATermMorph revive failed: ', e messageText ] ]
]

{
	#category : #menu,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> addModelItemsToWindowMenu: aMenu [
	"Extend the SystemWindow title-bar menu with terminal options."
	aMenu addLine.
	self addTerminalItemsToMenu: aMenu.
	aMenu addLine.
	aMenu add: 'restart shell' translated target: self selector: #restartShell.
	aMenu add: 'stop shell' translated target: self selector: #stopShell.
	aMenu addLine.
	aMenu addUpdating: #debugEventsMenuLabel target: self selector: #toggleDebugEvents argumentList: #().
]

{
	#category : #menu,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:51'
}
SWATermMorph >> addTerminalItemsToMenu: aMenu [
	"Shared copy/paste/select items used by both the right-click menu and the
	 SystemWindow title-bar menu."
	aMenu add: 'copy' translated target: self selector: #copySelection.
	aMenu add: 'paste' translated target: self selector: #paste.
	aMenu addLine.
	aMenu add: 'select all' translated target: self selector: #selectAll.
	aMenu add: 'clear selection' translated target: self selector: #clearSelection.
	aMenu addLine.
	aMenu add: 'choose font...' translated target: self selector: #chooseFont.
	aMenu add: 'grow font (Ctrl+)' translated target: self selector: #growFont.
	aMenu add: 'shrink font (Ctrl-)' translated target: self selector: #shrinkFont.
	aMenu add: 'reset font (Ctrl0)' translated target: self selector: #resetFont.
	"disable copy when nothing is selected"
	self hasSelection ifFalse: [
		(aMenu items detect: [ :it | it contents asString = 'copy' ] ifNone: [ nil ])
			ifNotNil: [ :it | it isEnabled: false ] ].
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> cellAtPoint: aPoint [
	"Map a world pixel position to a grid cell as col@row (0-based), clamped to the grid."
	| local col row |
	local := aPoint - self topLeft.
	col := (local x // cellWidth) max: 0.
	row := (local y // cellHeight) max: 0.
	col := col min: terminal cols - 1.
	row := row min: terminal rows - 1.
	^ col @ row
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:53'
}
SWATermMorph >> chooseFont [
	"Pop up a font chooser: every TrueType family loaded in the image (the
	 current one check-marked), plus -- when the preferred Cascadia Mono is not
	 installed -- an entry to download it from the Nerd Fonts release."
	| menu current |
	menu := MenuMorph new.
	menu addTitle: 'Terminal font'.
	current := font familyName asString.
	self class availableFontFamilies do: [ :fam |
		| item |
		item := MenuItemMorph new
			target: self;
			selector: #chooseFontFamily:;
			arguments: { fam }.
		item contents: ((fam = current ifTrue: [ '<yes>' ] ifFalse: [ '<no>' ]), fam)
			withMarkers: true.
		menu addMorphBack: item ].
	(self class availableFontFamilies includes: self class fontFamilyName) ifFalse: [
		menu addLine.
		menu add: 'Download Cascadia Mono...' translated
			target: self selector: #downloadAndUsePreferredFont ].
	menu popUpInWorld: self world
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:51'
}
SWATermMorph >> chooseFontFamily: familyName [
	"Switch this terminal to familyName, keeping the current point size. Warn (but
	 still switch) if the family lacks braille/block glyphs the terminal relies on."
	| newFont |
	newFont := TTCFont familyName: familyName pointSize: font pointSize.
	self font: newFont.
	((newFont hasGlyphOf: (Character value: 16r280B))
		and: [ newFont hasGlyphOf: (Character value: 16r2580) ])
		ifFalse: [ self class logLine: familyName,
			' lacks braille/block glyphs; spinners or progress bars may show as "?"' ]
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:17'
}
SWATermMorph >> clampSelection [
	"Keep selection endpoints inside the (possibly shrunk) grid, or drop them."
	| clamp |
	self hasSelection ifFalse: [ ^ self ].
	clamp := [ :p | ((p x max: 0) min: terminal cols - 1) @ ((p y max: 0) min: terminal rows - 1) ].
	selectionStart := clamp value: selectionStart.
	selectionEnd := clamp value: selectionEnd.
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> clearSelection [
	selectionStart := selectionEnd := nil.
	self changed.
]

{
	#category : #clipboard,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> copySelection [
	"Copy the selected text to the system clipboard."
	| text |
	self hasSelection ifFalse: [ ^ self ].
	text := self selectedText.
	Clipboard clipboardText: text.
	self logEvent: [ 'copy ', text size printString, ' chars' ].
]

{
	#category : #menu,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:11'
}
SWATermMorph >> debugEventsMenuLabel [
	"Checkmark toggle label: '<on>'/'<off>' prefix renders a check in the menu."
	^ (self class debugEvents ifTrue: [ '<on>' ] ifFalse: [ '<off>' ]),
		'log events to Transcript' translated
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:05'
}
SWATermMorph >> delete [
	"Note: SystemWindow>>collapseOrExpand sends #delete to pane morphs on
	 *collapse* (minimize), not just on window close. So delete must NOT tear
	 down the terminal/shell -- otherwise expanding the window redraws a morph
	 whose terminal is nil (doesNotUnderstand: #rows). Real teardown happens in
	 #windowIsClosing, which is only invoked on actual window close."
	super delete.
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:51'
}
SWATermMorph >> downloadAndUsePreferredFont [
	"Download (with confirm) + install the preferred Cascadia Mono font, then
	 switch this terminal to it. No-op if the user declines or it fails."
	| dir installed |
	dir := self class fontDirectory.
	(self class fontFileNames allSatisfy: [ :f | dir fileExists: f ])
		ifFalse: [ (self class confirmAndDownloadFontInto: dir) ifFalse: [ ^ self ] ].
	installed := self class installFontFilesFrom: dir.
	installed ifNil: [ ^ self class logLine: 'install produced no font' ].
	self chooseFontFamily: installed
]

{
	#category : #drawing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> drawCell: cell row: row col: col origin: origin on: aCanvas [
	"Draw one cell: background fill (if non-default) then the glyph."
	| x y fg bg ch cellBounds selected |
	cell ifNil: [ ^ self ].
	x := origin x + (col * cellWidth).
	y := origin y + (row * cellHeight).
	fg := cell fgColor ifNil: [ defaultFg ].
	bg := cell bgColor ifNil: [ defaultBg ].
	cell reverse ifTrue: [ | t | t := fg. fg := bg. bg := t ].
	selected := self isCellSelectedRow: row col: col.
	selected ifTrue: [ | t | t := fg. fg := bg. bg := t ].
	cellBounds := (x @ y) extent: (cellWidth @ cellHeight).
	bg = defaultBg ifFalse: [ aCanvas fillRectangle: cellBounds color: bg ].
	ch := cell character.
	ch = $  ifTrue: [ ^ self ].
	aCanvas
		drawString: (String with: ch)
		at: (x @ y)
		font: font
		color: fg.
	cell bold ifTrue: [
		aCanvas drawString: (String with: ch) at: (x + 1 @ y) font: font color: fg ].
	cell underline > 0 ifTrue: [
		aCanvas line: (x @ (y + cellHeight - 2)) to: (x + cellWidth @ (y + cellHeight - 2)) width: 1 color: fg ].
]

{
	#category : #drawing,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:13'
}
SWATermMorph >> drawCursorOn: aCanvas origin: origin [
	"Draw a block cursor at the terminal cursor position."
	| pos x y cursorBounds cell |
	pos := terminal cursorPos.
	x := origin x + (pos x * cellWidth).
	y := origin y + (pos y * cellHeight).
	cursorBounds := (x @ y) extent: (cellWidth @ cellHeight).
	self hasFocus
		ifTrue: [
			"Blink: only draw the solid block on the 'on' phase. On the 'off'
			 phase we draw nothing, leaving the cell that drawOn: already painted."
			blinkState ifTrue: [
				aCanvas fillRectangle: cursorBounds color: defaultFg.
				cell := terminal cellAt: pos y at: pos x.
				(cell notNil and: [ cell character ~= $  ]) ifTrue: [
					aCanvas drawString: (String with: cell character)
						at: (x @ y) font: font color: defaultBg ] ] ]
		ifFalse: [
			aCanvas frameRectangle: cursorBounds width: 1 color: defaultFg ].
]

{
	#category : #drawing,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:05'
}
SWATermMorph >> drawOn: aCanvas [
	"Draw the full terminal grid: background rectangle, then each cell's
	 background and glyph, then the cursor."
	| origin |
	origin := self topLeft.
	aCanvas fillRectangle: self bounds color: defaultBg.
	terminal ifNil: [ ^ self ].
	0 to: terminal rows - 1 do: [ :row |
		0 to: terminal cols - 1 do: [ :col |
			self drawCell: (terminal cellAt: row at: col)
				row: row col: col
				origin: origin on: aCanvas ] ].
	self drawCursorOn: aCanvas origin: origin.
]

{
	#category : #geometry,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:17'
}
SWATermMorph >> extent: aPoint [
	"When the morph is resized (e.g. by dragging the window edge), recompute the
	 grid dimensions from the new pixel size and resize the emulator + PTY."
	super extent: aPoint.
	self updateGridForExtent
]

{
	#category : #emulation,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:49'
}
SWATermMorph >> feed: bytesOrString [
	"Feed emulator output and request a redraw."
	terminal feed: bytesOrString.
	self changed.
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:31'
}
SWATermMorph >> font [
	^ font
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:01'
}
SWATermMorph >> font: aFont [
	"Set the rendering font and recompute the cell metrics. The font should be
	 fixed-width; cell size is taken from the width of $m and the font height.
	 Keep the character grid (rows x cols) constant across a size change: resize
	 the enclosing window to fit the new cell size rather than reflowing the grid
	 to the old pixel extent."
	font := aFont.
	cellWidth := font widthOf: $m.
	cellHeight := font height.
	self resizeWindowToGrid.
	self changed.
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:10'
}
SWATermMorph >> fontFamily: familyName [
	"Switch to a different font family, keeping the current point size."
	self font: (TTCFont familyName: familyName pointSize: font pointSize)
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:10'
}
SWATermMorph >> fontSize: points [
	"Switch to the same family at a new point size."
	| family |
	family := font familyName.
	self font: (TTCFont familyName: family pointSize: points)
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:54'
}
SWATermMorph >> forwardInput [
	"Drain libvterm's encoded keyboard output and write it to the PTY."
	| reply |
	reply := terminal drainOutput.
	reply isEmpty ifFalse: [ pty write: reply ].
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:10'
}
SWATermMorph >> growFont [
	self fontSize: (font pointSize + 1 min: 48)
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:04'
}
SWATermMorph >> handleClipboardShortcut: evt [
	"Intercept Ctrl+C / Ctrl+V for clipboard, following the common terminal convention:
	  - Ctrl+V always pastes.
	  - Ctrl+C copies when there is a selection, otherwise falls through so the shell
	    receives the interrupt (SIGINT).
	 Returns true if the event was consumed (caller should stop), false to continue
	 normal keystroke processing.
	 Ctrl-letter may arrive EITHER as a raw control code (Ctrl+C = 3, Ctrl+V = 22)
	 OR as the plain letter (c = 99, v = 118) with the control bit set -- depends on
	 the VM/keymap (on X11/WSL it is the plain letter). Normalize to the base letter."
	| code letter |
	evt controlKeyPressed ifFalse: [ ^ false ].
	code := evt keyCharacter asInteger.
	"Recover the base letter: raw control codes 1-26 -> a..z, else the char as-is."
	letter := (code between: 1 and: 26)
		ifTrue: [ Character value: code + 96 ]
		ifFalse: [ evt keyCharacter asLowercase ].
	"Ctrl+V: always paste."
	letter = $v ifTrue: [ self paste. ^ true ].
	"Ctrl+C: copy only if something is selected; else let SIGINT through."
	letter = $c ifTrue: [
		self hasSelection ifTrue: [
			self copySelection.
			self clearSelection.
			^ true ] ].
	^ false
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:02'
}
SWATermMorph >> handleFontShortcut: evt [
	"Intercept Ctrl++ / Ctrl+- (and Ctrl+0) to change the terminal font size,
	 following the common convention used by browsers and terminals:
	  - Ctrl++ (or Ctrl+=) grows the font.
	  - Ctrl+- shrinks the font.
	  - Ctrl+0 resets to the default size.
	 Returns true if the event was consumed, false to continue normal processing.
	 The '+' and '=' share a key; Squeak may deliver either depending on shift."
	| code letter |
	evt controlKeyPressed ifFalse: [ ^ false ].
	code := evt keyCharacter asInteger.
	letter := (code between: 1 and: 26)
		ifTrue: [ Character value: code + 96 ]
		ifFalse: [ evt keyCharacter ].
	(letter = $+ or: [ letter = $= ]) ifTrue: [ self growFont. ^ true ].
	letter = $- ifTrue: [ self shrinkFont. ^ true ].
	letter = $0 ifTrue: [ self resetFont. ^ true ].
	^ false
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:54'
}
SWATermMorph >> handlesKeyboard: evt [
	^ true
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:54'
}
SWATermMorph >> handlesMouseDown: evt [
	^ true
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> handlesMouseMove: evt [
	"Track drags while selecting."
	^ selecting == true
]

{
	#category : #testing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:49'
}
SWATermMorph >> hasFocus [
	^ self hasKeyboardFocus
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> hasSelection [
	^ selectionStart notNil and: [ selectionEnd notNil
		and: [ selectionStart ~= selectionEnd ] ]
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:36'
}
SWATermMorph >> initialize [
	super initialize.
	font := self class defaultFont.
	cellWidth := font widthOf: $m.
	cellHeight := font height.
	defaultFg := Color white.
	defaultBg := Color black.
	blinkState := true.
	terminal := SWATerm rows: 24 cols: 80.
	self hResizing: #spaceFill; vResizing: #spaceFill.
	self bounds: (0@0 extent: self preferredExtent).
	self color: defaultBg.
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> isCellSelectedRow: row col: col [
	"True if the cell (0-based) falls within the current selection, using
	 linear (stream) selection semantics like a normal terminal: everything
	 from the start cell to the end cell in reading order."
	| sel first last cellPos startPos endPos |
	sel := self orderedSelection.
	sel ifNil: [ ^ false ].
	first := sel first.
	last := sel second.
	"linear index = row * cols + col"
	cellPos := row * terminal cols + col.
	startPos := first y * terminal cols + first x.
	endPos := last y * terminal cols + last x.
	^ cellPos >= startPos and: [ cellPos <= endPos ]
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:14'
}
SWATermMorph >> keyStroke: evt [
	"Translate a Squeak keystroke into libvterm keyboard input, then forward the
	 encoded bytes to the PTY. VTermModifier: shift=1, alt=2, ctrl=4."
	| char code mod special |
	pty ifNil: [ ^ self ].
	"Clipboard shortcuts take priority (Ctrl+V paste; Ctrl+C copy when selected)."
	(self handleClipboardShortcut: evt) ifTrue: [ ^ evt wasHandled: true ].
	(self handleFontShortcut: evt) ifTrue: [ ^ evt wasHandled: true ].
	char := evt keyCharacter.
	code := char asInteger.
	mod := 0.
	evt shiftPressed ifTrue: [ mod := mod bitOr: 1 ].
	"VTermModifier: shift=1, alt=2, ctrl=4.
	 On X11/WSL the VM reports Ctrl in BOTH the ctrl and command bits (Ctrl doubles
	 as the command key). So only treat command as Alt/Meta when Ctrl is NOT down,
	 otherwise Ctrl-X would wrongly become Ctrl-Alt-X."
	(evt commandKeyPressed and: [ evt controlKeyPressed not ])
		ifTrue: [ mod := mod bitOr: 2 ].
	evt controlKeyPressed ifTrue: [ mod := mod bitOr: 4 ].
	self logEvent: [ 'keyStroke: ', evt keyString, ' code=', code printString, ' mod=', mod printString ].
	special := (self navigationKeyFor: evt) ifNil: [ self specialKeyFor: code ].
	special notNil
		ifTrue: [ terminal keyCode: special mod: mod ]
		ifFalse: [
			"Ctrl combos: Squeak may deliver the raw control code (1-26); libvterm
			 wants the base letter + ctrl modifier. Recover it when ctrl is down."
			(evt controlKeyPressed and: [ code between: 1 and: 26 ])
				ifTrue: [ terminal keyChar: (Character value: code + 96) mod: mod ]
				ifFalse: [ terminal keyChar: char mod: mod ] ].
	self forwardInput.
	evt wasHandled: true.
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:13'
}
SWATermMorph >> keyboardFocusChange: aBoolean [
	"Redraw so the cursor style (solid vs outline) updates."
	self logEvent: [ 'keyboardFocusChange: ', aBoolean printString ].
	blinkState := true.
	self changed.
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:06'
}
SWATermMorph >> logEvent: aStringBlock [
	"Print an event-routing diagnostic to the Transcript, but only when the
	 'Debug terminal input events' preference is on. Takes a block so the
	 (possibly costly) string is not built when logging is off."
	self class debugEvents ifTrue: [ Transcript showln: 'SWATerm ', aStringBlock value ]
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> mouseDown: evt [
	"Grab keyboard focus so typing goes to the shell."
	self logEvent: [ 'mouseDown: at ', evt position printString,
		' yellow=', evt yellowButtonChanged printString ].
	evt hand newKeyboardFocus: self.
	evt yellowButtonChanged
		ifTrue: [ ^ self yellowButtonActivity: evt shiftPressed ].
	"Left button: begin a text selection."
	selecting := true.
	selectionStart := self cellAtPoint: evt position.
	selectionEnd := selectionStart.
	self changed.
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> mouseMove: evt [
	"Extend the selection to the current cell while dragging."
	selecting == true ifFalse: [ ^ self ].
	selectionEnd := self cellAtPoint: evt position.
	self changed.
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> mouseUp: evt [
	"Finish a selection drag. A click without movement clears the selection."
	selecting == true ifFalse: [ ^ self ].
	selecting := false.
	selectionEnd := self cellAtPoint: evt position.
	self hasSelection ifFalse: [ selectionStart := selectionEnd := nil ].
	self changed.
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:14'
}
SWATermMorph >> navigationKeyFor: evt [
	"Map Home/End/PageUp/PageDown/Insert to VTermKey values. Squeak delivers
	 these as low codes that collide with control characters (Home=1 == Ctrl+A,
	 End=4 == Ctrl+D, pageUp=11 == Ctrl+K, pageDown=12 == Ctrl+L, insert=5 ==
	 Ctrl+E), so only treat them as navigation keys when no control key is held --
	 that way a genuine Ctrl+A etc. still passes through to the shell. Answer the
	 VTermKey enum value, or nil if this is not a (bare) navigation key."
	evt controlKeyPressed ifTrue: [ ^ nil ].
	evt commandKeyPressed ifTrue: [ ^ nil ].
	^ evt keyCharacter asInteger caseOf: {
		[ 1 ] -> [ terminal keyHome ].
		[ 4 ] -> [ terminal keyEnd ].
		[ 11 ] -> [ terminal keyPageUp ].
		[ 12 ] -> [ terminal keyPageDown ].
		[ 5 ] -> [ terminal keyInsert ]
	} otherwise: [ nil ]
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:07'
}
SWATermMorph >> openInWindow [
	"Open this terminal in a SystemWindow labeled 'Terminal', wired as the window's
	 model so the title-bar menu shows the terminal options. Returns the window."
	^ self openInWindowLabeled: 'Terminal' inWorld: self currentWorld
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:18'
}
SWATermMorph >> openInWindowLabeled: aString inWorld: aWorld [
	"Open in a SystemWindow and register myself as its model so the title-bar
	 menu can be extended (see addModelItemsToWindowMenu:)."
	| window |
	window := super openInWindowLabeled: aString inWorld: aWorld.
	window model: self.
	"Size the window so the grid fits exactly, accounting for the title bar/borders."
	window extent: self preferredExtent + (window extent - window layoutBounds extent).
	"Prevent collapsing to an unusable size (roughly a 20x4 grid)."
	window minimumExtent: (20 * cellWidth) @ (4 * cellHeight + 24).
	^ window
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> orderedSelection [
	"Return {topLeftCell. bottomRightCell} in reading order (row-major),
	 or nil if there is no selection. Cells are col@row (0-based)."
	| a b |
	self hasSelection ifFalse: [ ^ nil ].
	a := selectionStart.
	b := selectionEnd.
	"reading order: earlier row first; same row -> earlier col first"
	(a y < b y or: [ a y = b y and: [ a x <= b x ] ])
		ifTrue: [ ^ { a. b } ]
		ifFalse: [ ^ { b. a } ]
]

{
	#category : #clipboard,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> paste [
	"Send the clipboard contents to the shell as if typed."
	| text |
	pty ifNil: [ ^ self ].
	text := Clipboard clipboardText.
	text isEmptyOrNil ifTrue: [ ^ self ].
	self logEvent: [ 'paste ', text size printString, ' chars' ].
	"Normalize line endings to CR (what a terminal expects for Enter)."
	text := text asString copyReplaceAll: (String with: Character lf) with: (String with: Character cr).
	pty write: text utf8Encoded.
]

{
	#category : #geometry,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:49'
}
SWATermMorph >> preferredExtent [
	"Size that exactly fits the terminal grid."
	^ (terminal cols * cellWidth) @ (terminal rows * cellHeight)
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:55'
}
SWATermMorph >> pty [
	^ pty
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 17:00'
}
SWATermMorph >> pumpOnce [
	"One iteration of the pump: drain PTY -> emulator, and emulator replies -> PTY.
	 Answer true if any data was moved this iteration (so the pump loop can keep
	 going without sleeping while output is still flowing), false when idle."
	| input reply moved |
	(terminal isNil or: [ terminal isDead ]) ifTrue: [
		"dead after image load: stop the pump WITHOUT touching stale fd/pid via FFI"
		pumpProcess ifNotNil: [ pumpProcess terminate. pumpProcess := nil ].
		^ false ].
	pty ifNil: [ ^ false ].
	input := pty readAvailable.
	input isNil ifTrue: [ self shellEnded. ^ false ].	"EOF: child exited"
	moved := false.
	input isEmpty ifFalse: [
		self logEvent: [ 'pty->emu ', input size printString, ' bytes: ',
			(input asString copyReplaceAll: (String with: (Character value: 27)) with: '<ESC>') ].
		terminal feed: input.
		self changed.
		moved := true ].
	reply := terminal drainOutput.
	reply isEmpty ifFalse: [
		self logEvent: [ 'emu->pty ', reply size printString, ' bytes' ].
		pty write: reply.
		moved := true ].
	^ moved
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:02'
}
SWATermMorph >> resetFont [
	"Restore the terminal font to the default point size."
	self fontSize: self class defaultFont pointSize
]

{
	#category : #geometry,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:01'
}
SWATermMorph >> resizeWindowToGrid [
	"Resize the enclosing SystemWindow so the current grid (terminal cols x rows)
	 fits exactly at the current cell size, keeping the character dimensions
	 constant when the font size changes. Also refresh the collapse floor. If we
	 are not in a window (bare morph), just size the morph to the grid."
	| window |
	terminal ifNil: [ ^ self ].
	(cellWidth isNil or: [ cellHeight isNil ]) ifTrue: [ ^ self ].
	window := self ownerThatIsA: SystemWindow.
	window isNil ifTrue: [ ^ self extent: self preferredExtent ].
	window minimumExtent: (20 * cellWidth) @ (4 * cellHeight + 24).
	window extent: self preferredExtent + (window extent - window layoutBounds extent)
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:11'
}
SWATermMorph >> restartShell [
	"Stop any running shell and start a fresh bash."
	self startShell
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/24/2026 14:45'
}
SWATermMorph >> reviveAfterSnapshot [
	"Called on image startUp (fresh load): the previous process's libvterm
	 handles and PTY are dead (beDead nulled them), so instead of leaving the
	 terminal a corpse, rebuild it and re-run the shell/command it remembered.

	 Order matters:
	  1. terminal reinit -- fresh libvterm emulator at the same grid, so isDead
	     becomes false and drawing/feeding work again.
	  2. pty respawn -- re-fork the remembered command (default bash if none),
	     resized to the current grid.
	  3. startPump -- resume the read/feed/write loop.
	 Idempotent-ish: safe to call on a terminal whose window was already closed
	 (terminal nil -> nothing to do)."
	terminal ifNil: [ ^ self ].
	terminal reinit.
	pty
		ifNil: [ self startShell ]
		ifNotNil: [
			pty respawn: terminal rows cols: terminal cols.
			self startPump ].
	self changed
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> rightTrim: aString [
	"Remove trailing spaces from aString."
	| i |
	i := aString size.
	[ i > 0 and: [ (aString at: i) = $  ] ] whileTrue: [ i := i - 1 ].
	^ aString copyFrom: 1 to: i
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> selectAll [
	"Select the entire visible grid."
	selectionStart := 0 @ 0.
	selectionEnd := (terminal cols - 1) @ (terminal rows - 1).
	self changed.
]

{
	#category : #selection,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:55'
}
SWATermMorph >> selectedText [
	"Extract the selected text as a String. Linear (stream) selection: from the
	 start cell through the end cell in reading order. Trailing blanks on each
	 spanned row are trimmed and a newline is inserted at row boundaries."
	| sel first last |
	sel := self orderedSelection.
	sel ifNil: [ ^ '' ].
	first := sel first.
	last := sel second.
	^ String streamContents: [ :s |
		first y to: last y do: [ :row |
			| startCol endCol lineStream line |
			startCol := row = first y ifTrue: [ first x ] ifFalse: [ 0 ].
			endCol := row = last y ifTrue: [ last x ] ifFalse: [ terminal cols - 1 ].
			lineStream := WriteStream on: (WideString new: 0).
			startCol to: endCol do: [ :col |
				lineStream nextPut: (terminal cellAt: row at: col) character ].
			line := lineStream contents.
			"trim trailing spaces on full-width row spans (typical terminal copy behavior)"
			row < last y ifTrue: [ line := line withBlanksTrimmed = '' 
				ifTrue: [ '' ] ifFalse: [ self rightTrim: line ] ].
			s nextPutAll: line.
			row < last y ifTrue: [ s nextPut: Character lf ] ] ]
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:53'
}
SWATermMorph >> shellEnded [
	"The child process closed the PTY. Tear down the pump."
	pty ifNotNil: [ pty close. pty := nil ].
	pumpProcess := nil.
	self changed.
]

{
	#category : #fonts,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:10'
}
SWATermMorph >> shrinkFont [
	self fontSize: (font pointSize - 1 max: 6)
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 16:14'
}
SWATermMorph >> specialKeyFor: code [
	"Map a Squeak key code to a VTermKey enum value, or nil if it is an ordinary char.
	 Squeak: 28=left 29=right 30=up 31=down 8=bs 9=tab 13=cr 27=esc.
	 Note: navigation keys whose codes collide with control characters (Home=1,
	 End=4, pageUp=11, pageDown=12, insert=5) are NOT handled here -- they are
	 resolved in #navigationKeyFor: which also inspects the modifier state, so a
	 real Ctrl+A/Ctrl+D still reaches the shell."
	code = 30 ifTrue: [ ^ terminal keyUp ].
	code = 31 ifTrue: [ ^ terminal keyDown ].
	code = 28 ifTrue: [ ^ terminal keyLeft ].
	code = 29 ifTrue: [ ^ terminal keyRight ].
	code = 13 ifTrue: [ ^ terminal keyEnter ].
	code = 10 ifTrue: [ ^ terminal keyEnter ].
	code = 8 ifTrue: [ ^ terminal keyBackspace ].
	code = 127 ifTrue: [ ^ terminal keyBackspace ].
	code = 9 ifTrue: [ ^ terminal keyTab ].
	code = 27 ifTrue: [ ^ terminal keyEscape ].
	^ nil
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:34'
}
SWATermMorph >> startCommand: cmd args: argArray [
	"Spawn a command over a PTY sized to the terminal grid and start pumping."
	self stopShell.
	pty := SWATermPty command: cmd args: argArray.
	pty spawnRows: terminal rows cols: terminal cols.
	self startPump.
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/27/2026 17:00'
}
SWATermMorph >> startPump [
	"Background process: read PTY output -> feed emulator -> forward emulator
	 replies -> PTY, redrawing when something changed. Runs until PTY closes."
	pumpProcess ifNotNil: [ pumpProcess terminate. pumpProcess := nil ].
	pumpProcess := [
		[ pty notNil and: [ pty masterFd >= 0 ] ] whileTrue: [
			"pumpOnce answers true when it moved data. While output keeps flowing
			 (e.g. `cat` of a big file) keep pumping with no sleep so the child
			 never blocks on a full PTY buffer; only sleep 16ms once idle. Cap the
			 burst and yield so a never-ending stream can't starve other processes."
			| burst |
			burst := 0.
			[ self pumpOnce and: [ (burst := burst + 1) < 64 ] ] whileTrue: [ ].
			burst = 0
				ifTrue: [ (Delay forMilliseconds: 16) wait ]
				ifFalse: [ Processor yield ] ]
	] newProcess.
	pumpProcess priority: Processor userBackgroundPriority.
	pumpProcess resume.
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:53'
}
SWATermMorph >> startShell [
	"Spawn /bin/bash over a PTY and start the pump loop."
	^ self startCommand: '/bin/bash' args: #('-i')
]

{
	#category : #'stepping and presenter',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:12'
}
SWATermMorph >> step [
	"Toggle the cursor blink state and redraw just the cursor cell."
	| pos x y |
	blinkState := blinkState not.
	terminal ifNil: [ ^ self ].
	pos := terminal cursorPos.
	x := self left + (pos x * cellWidth).
	y := self top + (pos y * cellHeight).
	self invalidRect: ((x @ y) extent: (cellWidth @ cellHeight))
]

{
	#category : #'stepping and presenter',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:12'
}
SWATermMorph >> stepTime [
	"Cursor blink interval in milliseconds."
	^ 500
]

{
	#category : #shell,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:53'
}
SWATermMorph >> stopShell [
	"Stop the pump and close the PTY."
	pumpProcess ifNotNil: [ pumpProcess terminate. pumpProcess := nil ].
	pty ifNotNil: [ pty close. pty := nil ].
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:49'
}
SWATermMorph >> terminal [
	^ terminal
]

{
	#category : #menu,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:11'
}
SWATermMorph >> toggleDebugEvents [
	self class debugEvents: self class debugEvents not
]

{
	#category : #geometry,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 15:17'
}
SWATermMorph >> updateGridForExtent [
	"Derive cols/rows from the current pixel extent and, if they changed, resize
	 the terminal model and the PTY (which signals the child via SIGWINCH)."
	| newCols newRows |
	terminal ifNil: [ ^ self ].
	cellWidth isNil ifTrue: [ ^ self ].
	newCols := (self width // cellWidth) max: 1.
	newRows := (self height // cellHeight) max: 1.
	(newCols = terminal cols and: [ newRows = terminal rows ]) ifTrue: [ ^ self ].
	terminal resizeRows: newRows cols: newCols.
	pty ifNotNil: [ pty resizeRows: newRows cols: newCols ].
	"Clamp any selection to the new bounds."
	self clampSelection.
	self changed.
]

{
	#category : #'stepping and presenter',
	#'squeak_changestamp' : 'MCPServer 7/27/2026 15:12'
}
SWATermMorph >> wantsSteps [
	"Blink the cursor."
	^ true
]

{
	#category : #'initialize-release',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 13:11'
}
SWATermMorph >> windowIsClosing [
	"Sent by our hosting SystemWindow when it is closed: tear down the shell
	 and release libvterm."
	self stopShell.
	terminal ifNotNil: [ terminal free. terminal := nil ].
]

{
	#category : #'event handling',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 14:56'
}
SWATermMorph >> yellowButtonActivity: shiftPressed [
	"Pop up the terminal context menu (copy/paste)."
	| menu |
	menu := MenuMorph new.
	self addTerminalItemsToMenu: menu.
	menu popUpInWorld: self world
]
