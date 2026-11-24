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
