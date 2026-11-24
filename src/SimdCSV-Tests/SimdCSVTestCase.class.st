"
I am the abstract test case of SimdCSV: the tests of my subclasses run twice, with `backendName` `#plugin` (skipped without a SimdCSVPlugin) and `#smalltalk`, the test hook `#backend` of `SimdCSVBackend` being set to `backendObject`.

On WebAssembly (`isSmall`) the inputs are smaller, and those of `#smalltalk` smaller still: see `largeSize:` and `exhaustiveLength:`.
"
Class {
	#name : 'SimdCSVTestCase',
	#superclass : 'ParametrizedTestCase',
	#instVars : [
		'backendName'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
SimdCSVTestCase class >> defaultTimeLimit [
	"The exhaustive tests take seconds, and more in the WebAssembly VMs on a busy machine"

	^ 300 seconds
]

{ #category : 'testing' }
SimdCSVTestCase class >> isAbstract [
	^ self == SimdCSVTestCase
]

{ #category : 'testing' }
SimdCSVTestCase class >> isSmall [
	"Whether the inputs are the small ones: on WebAssembly, which the plugin tells"

	^ (SimdCSVPrimitives info ifNotNil: [ :info | info at: 5 ]) = 'emscripten'
]

{ #category : 'building suites' }
SimdCSVTestCase class >> testParameters [
	^ ParametrizedTestMatrix new
		  forSelector: #backendName addOptions: #( #plugin #smalltalk );
		  yourself
]

{ #category : 'asserting' }
SimdCSVTestCase >> assert: aBlock fails: aSymbol [
	"aBlock, a call of backendObject, answers the failure aSymbol"

	| answer |
	answer := aBlock value.
	self assert: answer simdCSVFailed description: [ 'the call answered ' , answer printString , ', not ' , aSymbol ].
	self assert: answer ec equals: aSymbol
]

{ #category : 'accessing' }
SimdCSVTestCase >> backendName [
	^ backendName
]

{ #category : 'accessing' }
SimdCSVTestCase >> backendName: aSymbol [
	backendName := aSymbol
]

{ #category : 'accessing' }
SimdCSVTestCase >> backendObject [
	"The object that answers the primitives for backendName"

	backendName == #plugin ifFalse: [ ^ SimdCSVSmalltalk ].
	SimdCSVBackend pluginAvailable ifFalse: [ self skip: 'no SimdCSVPlugin' ].
	^ SimdCSVPrimitives
]

{ #category : 'helpers' }
SimdCSVTestCase >> bytes: aString [
	"aString as a ByteArray, one byte a character"

	^ aString asByteArray
]

{ #category : 'helpers' }
SimdCSVTestCase >> exhaustiveLength: anInteger [
	"The length of the strings of an exhaustive test: one less on WebAssembly, and two less there for #smalltalk"

	self class isSmall ifFalse: [ ^ anInteger ].
	^ anInteger - (backendName == #plugin
		   ifTrue: [ 1 ]
		   ifFalse: [ 2 ])
]

{ #category : 'helpers' }
SimdCSVTestCase >> flags: aCollection [
	"The sum of the flags of the dialect word named by the Symbols of aCollection"

	^ aCollection inject: 0 into: [ :sum :each |
		  sum + (SimdCSVDialect perform: ('flag' , each capitalized) asSymbol) ]
]

{ #category : 'helpers' }
SimdCSVTestCase >> index: aSource flags: anInteger [
	"{ the answer of an index of the whole aSource, comma and double quote. its entries, an Array }"

	^ self index: aSource word: (self wordFlags: anInteger)
]

{ #category : 'helpers' }
SimdCSVTestCase >> index: aSource word: word [
	"{ the answer of an index of the whole aSource. its entries, an Array }"

	| dest answer |
	dest := WordArray new: aSource size + 1.
	answer := self backendObject index: aSource base: 1 from: 1 to: aSource size dialect: word into: dest from: 1.
	answer simdCSVFailed ifTrue: [ self fail: answer printString ].
	^ {
		  answer.
		  ((dest copyFrom: 1 to: (answer at: 2)) asArray) }
]

{ #category : 'helpers' }
SimdCSVTestCase >> largeSize: anInteger [
	"The size of a large input: a tenth on WebAssembly, and a hundredth there for #smalltalk"

	self class isSmall ifFalse: [ ^ anInteger ].
	^ anInteger // (backendName == #plugin
		   ifTrue: [ 10 ]
		   ifFalse: [ 100 ])
]

{ #category : 'helpers' }
SimdCSVTestCase >> random [
	"A Random with a fixed seed, so that a failure can be replayed"

	^ Random seed: 20261124
]

{ #category : 'running' }
SimdCSVTestCase >> setUp [
	| object |
	super setUp.
	SimdCSVBackend clearTestHooks.
	object := self backendObject.
	SimdCSVBackend testHook: #backend value: object
]

{ #category : 'helpers' }
SimdCSVTestCase >> stringsOver: anAlphabet upTo: length do: aBlock [
	"Evaluate aBlock with every String over the Characters of anAlphabet of 0 to length characters"

	0 to: length do: [ :size |
		0 to: (anAlphabet size raisedTo: size) - 1 do: [ :number |
			| string rest |
			string := String new: size.
			rest := number.
			1 to: size do: [ :i |
				string at: i put: (anAlphabet at: rest \\ anAlphabet size + 1).
				rest := rest // anAlphabet size ].
			aBlock value: string ] ]
]

{ #category : 'running' }
SimdCSVTestCase >> tearDown [
	SimdCSVBackend clearTestHooks.
	super tearDown
]

{ #category : 'helpers' }
SimdCSVTestCase >> wide: aString [
	"aString as a WideString"

	| wide |
	wide := WideString new: aString size.
	1 to: aString size do: [ :i | wide basicAt: i put: (aString basicAt: i) ].
	^ wide
]

{ #category : 'helpers' }
SimdCSVTestCase >> wordFlags: anInteger [
	"The dialect word of commas and double quotes with the flags anInteger"

	^ self wordSeparator: $, quote: $" flags: anInteger
]

{ #category : 'helpers' }
SimdCSVTestCase >> wordSeparator: aCharacter quote: anotherCharacter flags: anInteger [
	"A dialect word"

	^ aCharacter asInteger + (anotherCharacter asInteger bitShift: 21) + (anInteger bitShift: 29)
]
