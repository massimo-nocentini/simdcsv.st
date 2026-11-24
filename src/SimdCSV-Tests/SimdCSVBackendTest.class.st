"
I test the choice of the backend, the retries, the growth of the object memory and the test hooks.
"
Class {
	#name : 'SimdCSVBackendTest',
	#superclass : 'SimdCSVSingleTestCase',
	#instVars : [
		'grown'
	],
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'running' }
SimdCSVBackendTest >> setUp [
	super setUp.
	grown := OrderedCollection new.
	SimdCSVBackend testHook: #grow value: [ :bytes | grown add: bytes ]
]

{ #category : 'helpers' }
SimdCSVBackendTest >> failure: aSymbol [
	^ SimdCSVFailure on: aSymbol
]

{ #category : 'helpers' }
SimdCSVBackendTest >> rowsOf: aBackend [
	SimdCSVBackend testHook: #backend value: aBackend.
	^ SimdCSVBackend
		  rows: 'a'
		  base: 1
		  to: 1
		  dialect: 0
		  index: (WordArray with: 1)
		  from: 1
		  to: 1
		  types: nil
		  fieldCount: 0
		  into: (Array new: 1)
		  from: 1
		  empty: nil
		  budget: -1
]

{ #category : 'tests' }
SimdCSVBackendTest >> testBatchBytes [
	self assert: SimdCSVBackend batchBytes equals: 1048576.
	SimdCSVBackend testHook: #batchBytes value: 7.
	self assert: SimdCSVBackend batchBytes equals: 7
]

{ #category : 'tests' }
SimdCSVBackendTest >> testBackend [
	SimdCSVBackend clearTestHooks.
	self assert: SimdCSVBackend backend equals: (SimdCSVBackend pluginAvailable
			 ifTrue: [ #plugin ]
			 ifFalse: [ #smalltalk ]).
	SimdCSVBackend testHook: #pluginMissing value: true.
	self assert: SimdCSVBackend backend equals: #smalltalk.
	self assert: SimdCSVBackend current identicalTo: SimdCSVSmalltalk.
	self assert: SimdCSVBackend pluginInfo isNil.
	self deny: SimdCSVBackend pluginAvailable.
	self assert: SimdCSVBackend pluginProblem isNil.
	self assert: SimdCSVBackend implementationName equals: 'smalltalk'.
	SimdCSVBackend testHook: #backend value: 42.
	self assert: SimdCSVBackend backend equals: #hook.
	self assert: SimdCSVBackend current equals: 42
]

{ #category : 'tests' }
SimdCSVBackendTest >> testBackendIsMemoised [
	"The plugin is asked once a session"

	| first |
	SimdCSVBackend clearTestHooks.
	first := SimdCSVBackend pluginInfo.
	self assert: SimdCSVBackend pluginInfo identicalTo: first.
	self assert: SimdCSVBackend info identicalTo: first
]

{ #category : 'tests' }
SimdCSVBackendTest >> testErrorsAreAnswers [
	"A status ERROR is left to the caller"

	self
		assert: (self rowsOf: (SimdCSVScriptedBackend answering: { #( 2 0 1 0 4 1 1 1 0 ) }))
		equals: #( 2 0 1 0 4 1 1 1 0 )
]

{ #category : 'tests' }
SimdCSVBackendTest >> testFailure [
	"Another failure signals SimdCSVArgumentError with its error code"

	[
	self rowsOf: (SimdCSVScriptedBackend answering: { self failure: #'bad index' }).
	self fail: 'no error' ]
		on: SimdCSVArgumentError
		do: [ :error |
			self assert: error ec equals: #'bad index'.
			self assert: error messageText equals: 'SimdCSV: primitive failed: ' , #'bad index' printString ].
	self should: [ SimdCSVBackend clearTestHooks. SimdCSVBackend measure: nil from: 1 to: 2 dialect: 0 ] raise: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVBackendTest >> testFailureClass [
	self assert: (self failure: nil) isNotFound.
	self assert: (self failure: #'not found') isNotFound.
	self deny: (self failure: #'bad index') isNotFound.
	self assert: (self failure: #'insufficient object memory') isNoMemory.
	self assert: (self failure: 9) isNoMemory.
	self deny: (self failure: nil) isNoMemory.
	self deny: (self failure: #'insufficient C memory') isNoMemory.
	self assert: (self failure: nil) simdCSVFailed.
	self deny: nil simdCSVFailed.
	self deny: #( 4 ) simdCSVFailed.
	self assert: (self failure: #'bad index') printString equals: 'a SimdCSVFailure(' , #'bad index' printString , ')'
]

{ #category : 'tests' }
SimdCSVBackendTest >> testForwarding [
	"The calls reach the backend with their arguments"

	| index rows |
	SimdCSVBackend clearTestHooks.
	index := WordArray new: 3.
	rows := Array new: 1.
	self
		assert: (SimdCSVBackend
				 index: 'a,b'
				 base: 1
				 from: 1
				 to: 3
				 dialect: (self wordFlags: 48)
				 into: index
				 from: 2)
		equals: #( 0 2 1 4 0 2 2 0 0 ).
	self assert: index equals: (WordArray withAll: #( 0 1 3 )).
	self assert: (SimdCSVBackend measure: 'a,b' from: 1 to: 3 dialect: (self wordFlags: 48)) equals: #( 0 1 2 4 0 0 0 ).
	self
		assert: (SimdCSVBackend
				 rows: 'a,b'
				 base: 1
				 to: 3
				 dialect: (self wordFlags: 16)
				 index: (WordArray withAll: #( 1 3 ))
				 from: 1
				 to: 2
				 types: nil
				 fieldCount: 3
				 into: rows
				 from: 1
				 empty: 0
				 budget: -1)
		equals: #( 0 1 3 0 0 0 0 0 0 ).
	self assert: rows equals: #( #( 'a' 'b' 0 ) )
]

{ #category : 'tests' }
SimdCSVBackendTest >> testGrowth [
	"NO_ROOM: grow by the need and 1 MiB, and call again"

	| backend |
	backend := SimdCSVScriptedBackend answering: { #( 4 0 1 0 0 0 0 0 5000 ). #( 0 1 2 0 0 0 0 0 0 ) }.
	self assert: (self rowsOf: backend) first equals: 0.
	self assert: backend calls equals: 2.
	self assert: grown asArray equals: #( 1053576 )
]

{ #category : 'tests' }
SimdCSVBackendTest >> testGrowthThenCollection [
	"NO_ROOM again: collect all the garbage, and call a last time"

	| backend collections |
	backend := SimdCSVScriptedBackend answering: {
			           #( 4 0 1 0 0 0 0 0 5000 ).
			           #( 4 0 1 0 0 0 0 0 5000 ).
			           #( 0 1 2 0 0 0 0 0 0 ) }.
	collections := Smalltalk vm parameterAt: 7.
	self assert: (self rowsOf: backend) first equals: 0.
	self assert: backend calls equals: 3.
	self assert: grown size equals: 1.
	self assert: (Smalltalk vm parameterAt: 7) > collections
]

{ #category : 'tests' }
SimdCSVBackendTest >> testNoGrowth [
	"The memory cannot grow: collect all the garbage at once"

	| backend |
	SimdCSVBackend testHook: #grow value: [ :bytes | OutOfMemory signal ].
	backend := SimdCSVScriptedBackend answering: {
			           #( 4 0 1 0 0 0 0 0 5000 ).
			           #( 4 0 1 0 0 0 0 0 5000 ) }.
	self should: [ self rowsOf: backend ] raise: OutOfMemory.
	self assert: backend calls equals: 2
]

{ #category : 'tests' }
SimdCSVBackendTest >> testNoMemory [
	"A primitive that failed for want of memory: the same with need 0"

	| backend |
	backend := SimdCSVScriptedBackend answering: { (self failure: #'insufficient object memory'). #( 0 1 1 2 0 0 0 ) }.
	SimdCSVBackend testHook: #backend value: backend.
	self assert: (SimdCSVBackend measure: 'a' from: 1 to: 1 dialect: 0) first equals: 0.
	self assert: grown asArray equals: #( 1048576 )
]

{ #category : 'tests' }
SimdCSVBackendTest >> testOutOfMemory [
	| backend |
	backend := SimdCSVScriptedBackend answering: {
			           #( 4 0 1 0 0 0 0 0 5000 ).
			           #( 4 0 1 0 0 0 0 0 5000 ).
			           (self failure: #'insufficient object memory').
			           #( 0 1 2 0 0 0 0 0 0 ) }.
	self should: [ self rowsOf: backend ] raise: OutOfMemory.
	self assert: backend calls equals: 3
]

{ #category : 'tests' }
SimdCSVBackendTest >> testPluginMissingBetweenCalls [
	"The call is answered by SimdCSVSmalltalk, and the plugin is asked again at the next one"

	| backend |
	backend := SimdCSVScriptedBackend answering: { (self failure: nil). (self failure: #'not found'). #( 0 9 9 9 0 0 0 ) }.
	SimdCSVBackend testHook: #backend value: backend.
	2 timesRepeat: [
		self assert: (SimdCSVBackend measure: 'a' from: 1 to: 1 dialect: (self wordFlags: 48)) equals: #( 0 1 1 2 0 0 0 ) ].
	self assert: (SimdCSVBackend measure: 'a' from: 1 to: 1 dialect: (self wordFlags: 48)) second equals: 9.
	self assert: backend calls equals: 3
]

{ #category : 'tests' }
SimdCSVBackendTest >> testProtocol [
	"A plugin of another protocol is not used, and the reason is told"

	SimdCSVBackend clearTestHooks.
	SimdCSVBackend pluginAvailable ifFalse: [ ^ self skip: 'no SimdCSVPlugin' ].
	SimdCSVBackend testHook: #protocol value: 2.
	self assert: SimdCSVBackend backend equals: #smalltalk.
	self deny: SimdCSVBackend pluginAvailable.
	self assert: SimdCSVBackend pluginInfo first equals: 2.
	self assert: SimdCSVBackend pluginProblem equals: 'the plugin speaks protocol 2, not 1'
]

{ #category : 'tests' }
SimdCSVBackendTest >> testRealGrowth [
	"Without the hook the object memory grows"

	SimdCSVBackend testHook: #grow value: nil.
	self
		assert: (self rowsOf: (SimdCSVScriptedBackend answering: { #( 4 0 1 0 0 0 0 0 5000 ). #( 0 1 2 0 0 0 0 0 0 ) })) first
		equals: 0
]

{ #category : 'tests' }
SimdCSVBackendTest >> testSession [
	"Another session asks again"

	SimdCSVBackend clearTestHooks.
	SimdCSVBackend current.
	SimdCSVBackend classVarNamed: #Current put: 42.
	self assert: SimdCSVBackend current equals: 42.
	SimdCSVBackend classVarNamed: #SessionToken put: Object new.
	self deny: SimdCSVBackend current equals: 42
]

{ #category : 'tests' }
SimdCSVBackendTest >> testSmalltalkInfo [
	| info |
	info := SimdCSVSmalltalk info.
	self assert: info size equals: 8.
	self assert: info first equals: 1.
	self assert: info fourth equals: 'smalltalk'
]

{ #category : 'helpers' }
SimdCSVBackendTest >> boundedRows: aString free: aCollection canGrow: aBoolean [
	"{ the answer, or the class of the error. what was done. the row }"

	| bytes index rows word answer |
	bytes := aString asByteArray.
	index := WordArray new: 70000.
	rows := Array new: 1.
	word := SimdCSVDialect comma wordFor: bytes final: true lines: false exact: false.
	answer := SimdCSVBackend index: bytes base: 1 from: 1 to: bytes size dialect: word into: index from: 1.
	SimdCSVTestBoundedBackend free: aCollection canGrow: aBoolean.
	answer := [
	          SimdCSVTestBoundedBackend
		          rows: bytes
		          base: 1
		          to: bytes size
		          dialect: word
		          index: index
		          from: 1
		          to: (answer at: 2)
		          types: nil
		          fieldCount: 0
		          into: rows
		          from: 1
		          empty: nil
		          budget: 4194304 ]
		          on: OutOfMemory
		          do: [ :error | error return: error class ].
	^ {
		  answer.
		  SimdCSVTestBoundedBackend log.
		  rows first }
]

{ #category : 'tests' }
SimdCSVBackendTest >> testBoundedRoom [
	"Nothing is done where there is room; else the memory grows, or all the garbage is collected"

	| answer |
	answer := self boundedRows: 'a,b' free: #( 2000000 ) canGrow: false.
	self assert: answer second equals: #(  ).
	self assert: answer third equals: #( 'a' 'b' ).
	answer := self boundedRows: 'a,b' free: #( 1000000 ) canGrow: true.
	self assert: answer second equals: { (#grow -> 16777216) }.
	self assert: answer third equals: #( 'a' 'b' ).
	answer := self boundedRows: 'a,b' free: #( 1000000 2000000 ) canGrow: false.
	self assert: (answer second collect: [ :each | each key ]) equals: #( #grow #collect ).
	self assert: answer third equals: #( 'a' 'b' ).
	"little is left: the record fits"
	answer := self boundedRows: 'a,b' free: #( 1000000 ) canGrow: false.
	self assert: (answer second collect: [ :each | each key ]) equals: #( #grow #collect ).
	self assert: answer third equals: #( 'a' 'b' )
]

{ #category : 'tests' }
SimdCSVBackendTest >> testBoundedRecord [
	"A record that does not fit, of which the plugin tells the size, is not begun; the bound of its size is 4 bytes for a byte"

	| text answer |
	text := String new: 3000000 withAll: $x.
	answer := self boundedRows: text , ',y' free: #( 2500000 ) canGrow: false.
	self assert: answer first equals: OutOfMemory.
	self assert: answer third isNil.
	self assert: answer second first key equals: #grow.
	self assert: (answer second first value between: 12000000 and: 16777216).
	self assert: answer second second key equals: #collect.
	answer := self boundedRows: text , ',y' free: #( 5000000 ) canGrow: false.
	SimdCSVBackend current == SimdCSVPrimitives ifTrue: [
		self assert: answer third second equals: 'y' ].
	answer := self boundedRows: text , ',y' free: #( 20000000 ) canGrow: false.
	self assert: answer second equals: #(  ).
	self assert: answer third second equals: 'y'
]

{ #category : 'tests' }
SimdCSVBackendTest >> testBoundedArguments [
	"What is not an index is left to the backend"

	SimdCSVTestBoundedBackend free: #( 0 ) canGrow: false.
	self
		should: [
			SimdCSVTestBoundedBackend
				rows: #[ 97 ]
				base: 1
				to: 1
				dialect: 44
				index: 'abcd'
				from: 1
				to: 1
				types: nil
				fieldCount: 0
				into: (Array new: 1)
				from: 1
				empty: nil
				budget: -1 ]
		raise: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVBackendTest >> testMeasureOnly [
	"The budget -2 makes nothing, and answers the bytes of the objects of the first record"

	| bytes index rows word answer |
	SimdCSVBackend current == SimdCSVPrimitives ifFalse: [ ^ self ].
	bytes := ('abc,' , (String new: 1000 withAll: $x) , ',' , String lf , 'd') asByteArray.
	index := WordArray new: 4.
	rows := Array new: 2.
	word := SimdCSVDialect comma wordFor: bytes final: true lines: false exact: false.
	SimdCSVBackend index: bytes base: 1 from: 1 to: bytes size dialect: word into: index from: 1.
	answer := SimdCSVPrimitives
		          rows: bytes
		          base: 1
		          to: bytes size
		          dialect: word
		          index: index
		          from: 1
		          to: 4
		          types: nil
		          fieldCount: 0
		          into: rows
		          from: 1
		          wideStringClass: WideString
		          empty: nil
		          budget: -2.
	self assert: answer equals: { SimdCSVBackend statusNoRoom. 0. 1. 0. 0. 0. 0. 0. (32 + 16 + 1008) }.
	self assert: rows equals: #( nil nil )
]
