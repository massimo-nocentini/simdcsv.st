"
I am `SimdCSVBackend` in a VM whose old space is bounded: the free bytes are those of `free:`, one after another, and I write down what is done about them.
"
Class {
	#name : 'SimdCSVTestBoundedBackend',
	#superclass : 'SimdCSVBackend',
	#classInstVars : [
		'free',
		'canGrow',
		'log'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
SimdCSVTestBoundedBackend class >> free: aCollection canGrow: aBoolean [
	free := aCollection asOrderedCollection.
	canGrow := aBoolean.
	log := OrderedCollection new
]

{ #category : 'accessing' }
SimdCSVTestBoundedBackend class >> log [
	^ log asArray
]

{ #category : 'testing' }
SimdCSVTestBoundedBackend class >> isBounded [
	^ true
]

{ #category : 'private' }
SimdCSVTestBoundedBackend class >> freeOldSpace [
	^ free size > 1
		  ifTrue: [ free removeFirst ]
		  ifFalse: [ free first ]
]

{ #category : 'private' }
SimdCSVTestBoundedBackend class >> grow: byteCount [
	log add: #grow -> byteCount.
	^ canGrow
]

{ #category : 'private' }
SimdCSVTestBoundedBackend class >> collectIfUseful: freeBytes need: byteCount [
	log add: #collect -> byteCount
]
