"
The baseline of [SimdCSV](https://github.com/massimo-nocentini/simdcsv.st): reading and writing CSV in Pharo 12 to 15, on the SimdCSVPlugin of the VM or in pure Smalltalk.

Groups:

- `Core` (the package `SimdCSV`, which needs no other project),
- `Tests` (`SimdCSV-Tests`),
- `NeoTests` (`SimdCSV-NeoTests`: the comparison with NeoCSV, which it loads; opt-in),
- `default` loads `Core` and `Tests`.
"
Class {
	#name : 'BaselineOfSimdCSV',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfSimdCSV',
	#package : 'BaselineOfSimdCSV'
}

{ #category : 'baselines' }
BaselineOfSimdCSV >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec
			baseline: 'NeoCSV'
			with: [ spec repository: 'github://svenvc/NeoCSV:01948fc/repository' ].
		spec
			package: 'SimdCSV';
			package: 'SimdCSV-Tests' with: [ spec requires: #( 'SimdCSV' ) ];
			package: 'SimdCSV-NeoTests' with: [ spec requires: #( 'SimdCSV' 'SimdCSV-Tests' 'NeoCSV' ) ].
		spec
			group: 'Core' with: #( 'SimdCSV' );
			group: 'Tests' with: #( 'SimdCSV-Tests' );
			group: 'NeoTests' with: #( 'SimdCSV-NeoTests' );
			group: 'default' with: #( 'Core' 'Tests' ) ]
]
