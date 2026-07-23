"
FFI mapping of libvterm's VTermScreenCell (0.1.4):
  typedef struct {
    uint32_t chars[6];          // offset 0, codepoints; chars[0] is the glyph
    char     width;             // offset 24 (+3 pad)
    VTermScreenCellAttrs attrs; // offset 28, packed bitfield (uint)
    VTermColor fg, bg;          // offset 32, 36 -- tagged union, byte0=type
  } VTermScreenCell;            // total 40 bytes

attrs bitfield (LSB first):
  bold:1 underline:2 italic:1 blink:1 reverse:1 strike:1 font:4 dwl:1 dhl:2

VTermColor (4 bytes): byte0 type; if type&1==0 -> RGB(byte1=r,byte2=g,byte3=b); else indexed, byte1=idx.

Accessors below (attrsWord, fgWord, bgWord, ch0, bold, underline, reverse, etc.) decode these.
"
Class {
	#name : #SWATermCell,
	#superclass : #ExternalStructure,
	#classVars : [
		'SystemColors'
	],
	#category : #SqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #palette,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:44'
}
SWATermCell class >> ansiColor: idx [
	"Standard xterm 256-color palette -> Squeak Color.
	 0-15 system, 16-231 6x6x6 cube, 232-255 grayscale."
	| i r g b lvl |
	i := idx.
	i < 16 ifTrue: [ ^ self systemColors at: i + 1 ].
	i < 232 ifTrue: [
		i := i - 16.
		r := i // 36.
		g := (i // 6) \\ 6.
		b := i \\ 6.
		lvl := [ :n | n = 0 ifTrue: [ 0 ] ifFalse: [ 55 + (n * 40) ] ].
		^ Color r: (lvl value: r) g: (lvl value: g) b: (lvl value: b) range: 255 ].
	"grayscale 232-255"
	lvl := 8 + ((i - 232) * 10).
	^ Color r: lvl g: lvl b: lvl range: 255
]

{
	#category : #'field definition',
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:42'
}
SWATermCell class >> fields [
	"VTermScreenCell, 40 bytes. Raw words; higher-level accessors decode bitfields/colors."
	^ #(
		(ch0 'ulong')
		(ch1 'ulong')
		(ch2 'ulong')
		(ch3 'ulong')
		(ch4 'ulong')
		(ch5 'ulong')
		(widthWord 'ulong')
		(attrsWord 'ulong')
		(fgWord 'ulong')
		(bgWord 'ulong')
	)
]

{
	#category : #palette,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:44'
}
SWATermCell class >> systemColors [
	"The 16 standard ANSI system colors (0-7 normal, 8-15 bright)."
	^ SystemColors ifNil: [ SystemColors := {
		Color r: 0 g: 0 b: 0 range: 255.
		Color r: 205 g: 0 b: 0 range: 255.
		Color r: 0 g: 205 b: 0 range: 255.
		Color r: 205 g: 205 b: 0 range: 255.
		Color r: 0 g: 0 b: 238 range: 255.
		Color r: 205 g: 0 b: 205 range: 255.
		Color r: 0 g: 205 b: 205 range: 255.
		Color r: 229 g: 229 b: 229 range: 255.
		Color r: 127 g: 127 b: 127 range: 255.
		Color r: 255 g: 0 b: 0 range: 255.
		Color r: 0 g: 255 b: 0 range: 255.
		Color r: 255 g: 255 b: 0 range: 255.
		Color r: 92 g: 92 b: 255 range: 255.
		Color r: 255 g: 0 b: 255 range: 255.
		Color r: 0 g: 255 b: 255 range: 255.
		Color r: 255 g: 255 b: 255 range: 255 } ]
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> bgColor [
	"Background as a Squeak Color, or nil for terminal default."
	^ self colorFromWord: self bgWord
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> bold [
	"attrs bit 0"
	^ (self attrsWord bitAnd: 1) = 1
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> character [
	"The primary character as a Character; space when blank."
	| cp |
	cp := self ch0.
	cp = 0 ifTrue: [ ^ $  ].
	^ Character value: cp
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> codepoint [
	"The primary character codepoint of this cell (0 means blank)."
	^ self ch0
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> colorFromWord: word [
	"Decode a VTermColor (4 bytes packed little-endian in a ulong).
	 byte0=type; if type even -> RGB(byte1,2,3); if odd (indexed) -> byte1=palette idx.
	 Returns a Squeak Color, or nil to mean 'use default fg/bg'."
	| type b1 b2 b3 |
	type := word bitAnd: 16rFF.
	b1 := (word bitShift: -8) bitAnd: 16rFF.
	b2 := (word bitShift: -16) bitAnd: 16rFF.
	b3 := (word bitShift: -24) bitAnd: 16rFF.
	(type bitAnd: 1) = 0
		ifTrue: [ ^ Color r: b1 g: b2 b: b3 range: 255 ]
		ifFalse: [
			"Indexed. type bit1 set => DEFAULT_FG/BG; return nil so caller applies its default."
			(type bitAnd: 2) ~= 0 ifTrue: [ ^ nil ].
			^ self class ansiColor: b1 ]
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> fgColor [
	"Foreground as a Squeak Color, or nil for terminal default."
	^ self colorFromWord: self fgWord
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> reverse [
	"attrs: bold:1 underline:2 italic:1 blink:1 reverse:1 -> reverse is bit 5"
	^ ((self attrsWord bitShift: -5) bitAnd: 1) = 1
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> underline [
	"attrs bits 1-2 (0=off,1=single,2=double,3=curly)"
	^ (self attrsWord bitShift: -1) bitAnd: 3
]

{
	#category : #decoding,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 12:43'
}
SWATermCell >> width [
	"Cell display width (1 normal, 2 for wide chars). Low byte of widthWord."
	^ self widthWord bitAnd: 16rFF
]
