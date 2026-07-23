"
Metacello baseline for the Squeak Terminal.

Load with:

	Metacello new
		baseline: 'SqueakTerminal';
		repository: 'github://hpi-swa-lab/squeak-terminal:main/src';
		load.
"
Class {
	#name : #BaselineOfSqueakTerminal,
	#superclass : #BaselineOf,
	#category : #BaselineOfSqueakTerminal,
	#'squeak_changestamp' : '<historical>'
}

{
	#category : #baselines,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 16:24'
}
BaselineOfSqueakTerminal >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec package: 'SqueakTerminal' ].
]

{
	#category : #accessing,
	#'squeak_changestamp' : 'MCPServer 7/23/2026 16:24'
}
BaselineOfSqueakTerminal >> projectClass [

	^ (self environment classNamed: #MetacelloCypressBaselineProject) ifNil: [super projectClass]
]
