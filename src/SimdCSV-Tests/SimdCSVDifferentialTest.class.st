"
I compare the answers of the plugin with those of `SimdCSVSmalltalk` on random calls, good and bad; I am skipped without the plugin.
"
Class {
	#name : 'SimdCSVDifferentialTest',
	#superclass : 'SimdCSVTestCase',
	#instVars : [
		'random'
	],
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'running' }
SimdCSVDifferentialTest >> setUp [
	super setUp.
	SimdCSVBackend pluginAvailable ifFalse: [ self skip: 'no SimdCSVPlugin' ].
	random := Random seed: 20261124
]

{ #category : 'asserting' }
SimdCSVDifferentialTest >> assert: aSelector with: arguments destination: position [
	"Both backends answer aSelector with arguments alike, each with a copy of the destination, the argument at position, and fill it alike"

	| plugin smalltalk one other answer |
	one := arguments copy.
	other := arguments copy.
	position = 0 ifFalse: [
		one at: position put: (arguments at: position) copy.
		other at: position put: (arguments at: position) copy ].
	plugin := SimdCSVPrimitives perform: aSelector withArguments: one.
	smalltalk := SimdCSVSmalltalk perform: aSelector withArguments: other.
	(plugin simdCSVFailed or: [ smalltalk simdCSVFailed ]) ifTrue: [
		^ (plugin simdCSVFailed and: [ smalltalk simdCSVFailed and: [ plugin ec == smalltalk ec ] ]) ifFalse: [
			  self fail: 'plugin ' , plugin printString , ' Smalltalk ' , smalltalk printString , ' for ' , arguments printString ] ].
	answer := plugin = smalltalk and: [
		          position = 0 or: [
			          | stored start |
			          start := arguments at: position + 1.
			          stored := plugin second.
			          ((one at: position) copyFrom: start to: start + stored - 1) = ((other at: position) copyFrom: start to: start + stored - 1)
				          and: [ ((one at: position) first: start - 1) = ((other at: position) first: start - 1) ] ] ].
	answer ifFalse: [
		self fail: 'plugin ' , plugin printString , ' Smalltalk ' , smalltalk printString , ' for ' , arguments printString ]
]

{ #category : 'helpers' }
SimdCSVDifferentialTest >> randomFlags [
	^ random nextInteger: 512
]

{ #category : 'helpers' }
SimdCSVDifferentialTest >> randomSource [
	"A ByteArray, a ByteString or a WideString over an alphabet drawn at random"

	| alphabet size bytes kind |
	alphabet := #( #[ 97 44 34 10 13 ] #[ 97 98 99 100 101 102 103 104 44 44 10 ] #[ 48 49 50 46 45 101 44 10 32 34 ] #[ 97 34 34 34 44 10 ]
	               #[ 195 169 226 130 172 240 159 152 128 97 44 34 10 ] #[ 0 255 44 34 10 13 128 ] ) at: (random nextInteger: 6).
	size := random nextInteger: ((random nextInteger: 4) = 1
			         ifTrue: [ 500 ]
			         ifFalse: [ 70 ]).
	bytes := ByteArray new: size.
	1 to: size do: [ :i | bytes at: i put: (alphabet at: (random nextInteger: alphabet size)) ].
	kind := random nextInteger: 4.
	kind = 1 ifTrue: [ ^ bytes asString ].
	kind = 2 ifTrue: [
		| wide |
		wide := WideString new: size.
		1 to: size do: [ :i | wide basicAt: i put: (bytes at: i) * ((random nextInteger: 50) = 1 ifTrue: [ 1000 ] ifFalse: [ 1 ]) ].
		^ wide ].
	^ bytes
]

{ #category : 'helpers' }
SimdCSVDifferentialTest >> randomWordFor: aSource [
	| flags |
	flags := self randomFlags - 1.
	flags := (SimdCSVSmalltalk unitsOf: aSource) == #words
		         ifTrue: [ flags bitAnd: 16 bitInvert ]
		         ifFalse: [ flags ].
	(random nextInteger: 10) = 1 ifTrue: [
		^ ((random nextInteger: 256) - 1) + ((random nextInteger: 256) - 1 bitShift: 21) + (flags bitShift: 29) ].
	^ self wordFlags: flags
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testInfo [
	| info |
	info := SimdCSVPrimitives info.
	self assert: info size equals: 8.
	self assert: info first equals: 1.
	self assert: info second equals: 'SimdCSVPlugin 1.0'.
	self assert: info third equals: 'a9494a8'.
	self assert: (info sixth includes: info fourth).
	self assert: info sixth last equals: 'fallback'.
	self assert: (#( 'native' 'emscripten' ) includes: info fifth).
	self assert: info last equals: SimdCSVSmalltalk maxSpan
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testIndex [
	(self largeSize: 20000) timesRepeat: [
		| source base from to dest |
		source := self randomSource.
		base := random nextInteger: source size + 1.
		from := base + (random nextInteger: 3) - 1.
		to := source size - ((random nextInteger: 5) - 1).
		dest := WordArray new: (random nextInteger: 80).
		self
			assert: #index:base:from:to:dialect:into:from:
			with: {
					source.
					base.
					from.
					to.
					(self randomWordFor: source).
					dest.
					(random nextInteger: 3) }
			destination: 6 ]
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testMeasure [
	(self largeSize: 10000) timesRepeat: [
		| source |
		source := self randomSource.
		self
			assert: #measure:from:to:dialect:
			with: {
					source.
					(random nextInteger: 5).
					(source size - ((random nextInteger: 5) - 1)).
					(self randomWordFor: source) }
			destination: 0 ]
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testRows [
	"The rows of the index of the source, or of an index that is wrong somewhere"

	(self largeSize: 20000) timesRepeat: [
		| source word index answer types count |
		source := self randomSource.
		word := self randomWordFor: source.
		index := WordArray new: source size + 1.
		answer := SimdCSVSmalltalk
			          index: source
			          base: 1
			          from: 1
			          to: source size
			          dialect: word
			          into: index
			          from: 1.
		answer simdCSVFailed ifFalse: [
			(random nextInteger: 5) = 1 ifTrue: [
				index at: (random nextInteger: index size) put: (random nextInteger: source size + 2) - 1 ].
			count := (random nextInteger: 4) - 1.
			types := (random nextInteger: 2) = 1 ifTrue: [
				         (ByteArray new: (count = 0
						           ifTrue: [ 3 ]
						           ifFalse: [ count ])) collect: [ :each | (random nextInteger: 5) - 1 ] ].
			self
				assert: #rows:base:to:dialect:index:from:to:types:fieldCount:into:from:wideStringClass:empty:budget:
				with: {
						source.
						1.
						source size.
						word.
						index.
						(random nextInteger: 2).
						(answer second min: index size).
						types.
						count.
						(Array new: (random nextInteger: 40)).
						(random nextInteger: 2).
						WideString.
						#empty.
						-1 }
				destination: 10 ] ]
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testBudget [
	"The plugin stops at the first record after the budget is used, one record being always tried; the calls together make the rows of one call"

	| source index count all |
	source := (String streamContents: [ :stream |
		           1 to: 300 do: [ :i | stream print: i; nextPutAll: ',abcdefghijklmnop,"x""y",1.5e30'; lf ] ]) asByteArray.
	index := WordArray new: 2000.
	count := (SimdCSVPrimitives index: source base: 1 from: 1 to: source size dialect: (self wordFlags: 32) into: index from: 1) second.
	all := Array new: 300.
	SimdCSVSmalltalk
		rows: source base: 1 to: source size dialect: (self wordFlags: 0) index: index from: 1 to: count
		types: #[ 2 1 1 3 ] fieldCount: 4 into: all from: 1 wideStringClass: WideString empty: nil budget: -1.
	#( 0 1 100 1000 100000 ) do: [ :budget |
		| rows next answer calls |
		rows := Array new: 300.
		next := 1.
		calls := 0.
		[
		answer := SimdCSVPrimitives
			          rows: source base: 1 to: source size dialect: (self wordFlags: 0) index: index from: next to: count
			          types: #[ 2 1 1 3 ] fieldCount: 4 into: rows from: next // 4 + 1 wideStringClass: WideString empty: nil budget: budget.
		calls := calls + 1.
		answer first = 1 ] whileTrue: [
			self assert: answer second > 0.
			self assert: (answer third - 1) \\ 4 equals: 0.
			next := answer third ].
		self assert: answer first equals: 0.
		self assert: rows equals: all.
		budget < 100 ifTrue: [ self assert: calls equals: 300 ].
		budget = 100000 ifTrue: [ self assert: calls < 10 ] ]
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testRowsOfRandomIndexes [
	(self largeSize: 5000) timesRepeat: [
		| source index |
		source := self randomSource.
		index := WordArray new: 20.
		1 to: 20 do: [ :i |
			index at: i put: ((random nextInteger: 30) = 1
					 ifTrue: [ 4294967295 - (random nextInteger: 5) ]
					 ifFalse: [ (random nextInteger: source size + 3) - 1 ]) ].
		self
			assert: #rows:base:to:dialect:index:from:to:types:fieldCount:into:from:wideStringClass:empty:budget:
			with: {
					source.
					(random nextInteger: 3).
					source size.
					(self randomWordFor: source).
					index.
					(random nextInteger: 4).
					(random nextInteger: 20).
					nil.
					0.
					(Array new: 20).
					1.
					WideString.
					nil.
					-1 }
			destination: 10 ]
]

{ #category : 'tests' }
SimdCSVDifferentialTest >> testNumbers [
	"The same cells are converted, to the same numbers"

	| cells source index count |
	cells := OrderedCollection new.
	(self largeSize: 20000) timesRepeat: [ cells add: self randomNumberText ].
	source := (String streamContents: [ :stream | cells do: [ :each | stream nextPutAll: each ] separatedBy: [ stream lf ] ]) asByteArray.
	index := WordArray new: source size.
	count := (SimdCSVPrimitives index: source base: 1 from: 1 to: source size dialect: (self wordFlags: 32) into: index from: 1) second.
	2 to: 4 do: [ :type |
		self
			assert: #rows:base:to:dialect:index:from:to:types:fieldCount:into:from:wideStringClass:empty:budget:
			with: {
					source.
					1.
					source size.
					(self wordFlags: 0).
					index.
					1.
					count.
					(ByteArray with: type).
					1.
					(Array new: count).
					1.
					WideString.
					nil.
					-1 }
			destination: 10 ]
]

{ #category : 'helpers' }
SimdCSVDifferentialTest >> randomNumberText [
	"A number, or nearly one"

	| digits |
	digits := [ :count |
	          String streamContents: [ :stream |
		          count timesRepeat: [
			          stream nextPut: ((random nextInteger: 3) = 1
					           ifTrue: [ $0 ]
					           ifFalse: [ '0123456789' at: (random nextInteger: 10) ]) ] ] ].
	^ String streamContents: [ :stream |
		  (random nextInteger: 8) = 1 ifTrue: [ stream space ].
		  stream nextPutAll: (#( '' '' '-' '+' '--' ) at: (random nextInteger: 5)).
		  stream nextPutAll: (digits value: (random nextInteger: 20) - 1).
		  (random nextInteger: 2) = 1 ifTrue: [
			  stream nextPutAll: (#( '.' '.' ',' '..' ) at: (random nextInteger: 4)).
			  stream nextPutAll: (digits value: (random nextInteger: 25) - 1) ].
		  (random nextInteger: 3) = 1 ifTrue: [
			  stream nextPutAll: (#( 'e' 'E' 'x' ) at: (random nextInteger: 3)).
			  stream nextPutAll: (#( '' '-' '+' ) at: (random nextInteger: 3)).
			  stream nextPutAll: (digits value: (random nextInteger: 3)) ].
		  (random nextInteger: 8) = 1 ifTrue: [ stream tab ] ]
]

{ #category : 'helpers' }
SimdCSVDifferentialTest >> backendObject [
	"I call both"

	^ SimdCSVSmalltalk
]

{ #category : 'building suites' }
SimdCSVDifferentialTest class >> testParameters [
	"The comparison is made once"

	^ ParametrizedTestMatrix new
		  forSelector: #backendName addOptions: #( #both );
		  yourself
]
