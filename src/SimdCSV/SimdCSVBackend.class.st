"
I choose between `SimdCSVPrimitives` (the `SimdCSVPlugin`, when the VM has one that speaks my protocol) and `SimdCSVSmalltalk` (the same answers in pure Smalltalk), on my class side only, and I call the chosen one.

The choice is made once a session (`current`, `backend`, `pluginInfo`); `resetBackend` forgets it.

## Calls

`measure:from:to:dialect:`, `index:base:from:to:dialect:into:from:` and `rows:base:to:dialect:index:from:to:types:fieldCount:into:from:empty:budget:` answer what the primitive answers (the comment of `SimdCSVPrimitives`), with one of the statuses OK, MORE, ERROR and TOO_LARGE (0 to 3). An ERROR is left to the caller. I handle the rest:

- a missing module: the call is answered by `SimdCSVSmalltalk`, once, and the plugin is asked again at the next call;
- NO_ROOM, or a primitive that failed because no object could be allocated: the object memory grows by the need and 1 MiB and the call is made again; then all the garbage is collected and the call is made a last time; then `OutOfMemory`;
- any other failure signals `SimdCSVArgumentError` with the error code of the primitive.

Where old space cannot grow at will (`isBounded`), a call for rows that fills it ends in OutOfMemory, or in the end of the VM, although a collection would have made room: the VM does not collect before. So I look at the free old space before such a call. When it may be too little, the object memory grows, or else all the garbage is collected; when it is still little the budget of the call is reduced, and when not even the first record fits, of which the plugin tells the size, I signal `OutOfMemory` and nothing is built.

## Test hooks

`testHook:value:`, where nil removes a hook, and `clearTestHooks`; each forgets the choice:

- `#pluginMissing` (true: as if the VM had no plugin);
- `#protocol` (an Integer: as if the plugin spoke this protocol);
- `#backend` (the object to call instead of the chosen one);
- `#grow` (a block of the byte count, evaluated instead of growing the object memory);
- `#batchBytes` (the size of the buffer of a reader, see `batchBytes`).
"
Class {
	#name : 'SimdCSVBackend',
	#superclass : 'Object',
	#classVars : [
		'CollectedFree',
		'Current',
		'PluginInfo',
		'SessionToken',
		'TestHooks'
	],
	#category : 'SimdCSV-Backends',
	#package : 'SimdCSV',
	#tag : 'Backends'
}

{ #category : 'accessing' }
SimdCSVBackend class >> backend [
	"What the calls go through: #plugin, #smalltalk, or #hook for another object set by the test hook #backend"

	| current |
	current := self current.
	current == SimdCSVPrimitives ifTrue: [ ^ #plugin ].
	current == SimdCSVSmalltalk ifTrue: [ ^ #smalltalk ].
	^ #hook
]

{ #category : 'accessing' }
SimdCSVBackend class >> batchBytes [
	"The default size in units of the buffer of a reader: 1 MiB, or the test hook #batchBytes"

	^ (self testHook: #batchBytes) ifNil: [ 1048576 ]
]

{ #category : 'private' }
SimdCSVBackend class >> boundOf: anIndex from: start to: stop records: count fieldCount: fieldCount [
	"At most the bytes of the objects of those entries: for each record an Array, for each field its slot, a header, an overflow header and the rounding or a boxed Float, and 4 bytes a unit"

	| units |
	units := (anIndex at: stop) - (start = 1
		          ifTrue: [ 0 ]
		          ifFalse: [ anIndex at: start - 1 ]) max: 0.
	^ count * (16 + (8 * (fieldCount max: 1))) + (stop - start + 1 * 32) + (4 * units)
]

{ #category : 'private' }
SimdCSVBackend class >> budget: budget first: firstBound all: allBound for: aBlock [
	"The budget of a call for rows where old space is bounded, so that what it makes fits there: at most the first record, or twice the budget and a record of 64 KiB, or all the records, of which the bounds are given. The object memory grows for it, or all the garbage is collected"

	| free need room |
	room := 1048576.
	free := self freeOldSpace.
	free >= (allBound + room) ifTrue: [ ^ budget ].
	need := budget < 0
		        ifTrue: [ allBound ]
		        ifFalse: [ (budget * 2 + 65536 max: firstBound) min: allBound ].
	free >= (need + room) ifTrue: [ ^ budget ].
	(self grow: (need + room - free max: 16777216)) ifTrue: [ ^ budget ].
	self collectIfUseful: free need: firstBound + room.
	free := self freeOldSpace.
	free >= (need + room) ifTrue: [ ^ budget ].
	(self needOf: aBlock ifNone: firstBound) > (free // 2 max: free - room) ifTrue: [ ^ OutOfMemory signal ].
	^ budget min: (free // 8 max: 4096)
]

{ #category : 'test hooks' }
SimdCSVBackend class >> clearTestHooks [
	"Remove every test hook, and forget the choice of the backend"

	TestHooks := nil.
	SessionToken := nil
]

{ #category : 'private' }
SimdCSVBackend class >> collectIfUseful: free need: byteCount [
	"Collect all the garbage; not again when there is room for a record, and less than 1 MiB of old space was used since the last time"

	(free >= byteCount and: [ CollectedFree notNil and: [ CollectedFree - free < 1048576 ] ]) ifTrue: [ ^ self ].
	Smalltalk garbageCollect.
	CollectedFree := self freeOldSpace
]

{ #category : 'accessing' }
SimdCSVBackend class >> current [
	"The object that answers the calls: the test hook #backend, SimdCSVPrimitives with a plugin of my protocol, else SimdCSVSmalltalk"

	SessionToken == Smalltalk session ifFalse: [ self resetBackend ].
	^ Current
]

{ #category : 'private' }
SimdCSVBackend class >> freeOldSpace [
	"The free bytes of old space"

	^ Smalltalk vm parameterAt: 54
]

{ #category : 'private' }
SimdCSVBackend class >> grow: byteCount [
	"Whether the object memory grew by at least byteCount bytes: growMemoryByAtLeast: signals OutOfMemory when it cannot (old space may have a maximum, as in WebAssembly), which is no error here: all the garbage is collected instead.  The test hook #grow, a block, is evaluated instead"

	^ [
	  (self testHook: #grow)
		  ifNil: [ Smalltalk growMemoryByAtLeast: byteCount ]
		  ifNotNil: [ :hook | hook value: byteCount ].
	  true ]
		  on: OutOfMemory
		  do: [ :error | error return: false ]
]

{ #category : 'accessing' }
SimdCSVBackend class >> implementationName [
	"The kernel of the plugin (avx2, sse2, neon or fallback), else smalltalk"

	^ self backend == #plugin
		  ifTrue: [ PluginInfo at: 4 ]
		  ifFalse: [ 'smalltalk' ]
]

{ #category : 'calls' }
SimdCSVBackend class >> index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom [
	"{ status. stored. records. next. lines. minFields. maxFields. code. position }, with a status 0 to 3"

	^ self run: [ :backend |
		  backend index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom ]
]

{ #category : 'calls' }
SimdCSVBackend class >> info [
	"What primitiveInfo answered this session, nil without the plugin"

	^ self pluginInfo
]

{ #category : 'testing' }
SimdCSVBackend class >> isBounded [
	"Can old space not grow at will, as in WebAssembly, or by the parameter 67 of the VM?"

	| info |
	info := self pluginInfo.
	^ (info notNil and: [ info size >= 5 and: [ (info at: 5) = 'emscripten' ] ]) or: [
		  ((Smalltalk vm parameterAt: 67) ifNil: [ 0 ]) > 0 ]
]

{ #category : 'private' }
SimdCSVBackend class >> isIndex: anIndex from: start to: stop [
	"Are there entries from start to stop? The backend refuses the rest"

	^ (anIndex isMemberOf: WordArray) and: [
		  start isInteger and: [ stop isInteger and: [ start >= 1 and: [ start <= stop and: [ stop <= anIndex size ] ] ] ] ]
]

{ #category : 'private' }
SimdCSVBackend class >> lastSlotIn: source base: base dialect: word index: anIndex from: start to: stop [
	"The entry that ends the record that begins at start: the first that is at no separator"

	| separator last size position |
	(base isInteger and: [ word isInteger ]) ifFalse: [ ^ stop ].
	separator := word bitAnd: 16r1FFFFF.
	size := source basicSize.
	last := start.
	[
	last < stop and: [
		position := base + (anIndex at: last).
		(position between: 1 and: size) and: [ (source basicAt: position) = separator ] ] ] whileTrue: [ last := last + 1 ].
	^ last
]

{ #category : 'calls' }
SimdCSVBackend class >> measure: source from: start to: stop dialect: word [
	"{ status. records. fields. next. lines. code. position }, with a status 0 or 2"

	^ self run: [ :backend | backend measure: source from: start to: stop dialect: word ]
]

{ #category : 'private' }
SimdCSVBackend class >> needOf: aBlock ifNone: aNumber [
	"The bytes of the objects of the first record, which the plugin tells for the budget -2, without making any; or aNumber"

	| answer |
	self current == SimdCSVPrimitives ifFalse: [ ^ aNumber ].
	answer := aBlock value: SimdCSVPrimitives value: -2.
	(answer simdCSVFailed or: [ answer first ~= self statusNoRoom ]) ifTrue: [ ^ 0 ].
	^ answer last
]

{ #category : 'accessing' }
SimdCSVBackend class >> pluginAvailable [
	"Whether the VM has a SimdCSVPlugin of my protocol"

	^ self pluginInfo notNil and: [ self pluginProblem isNil ]
]

{ #category : 'accessing' }
SimdCSVBackend class >> pluginInfo [
	"What primitiveInfo answered this session, whatever its protocol (its first element), or nil without the plugin"

	self current.
	^ PluginInfo
]

{ #category : 'accessing' }
SimdCSVBackend class >> pluginProblem [
	"Why a plugin that is there is not used, a String, or nil"

	^ self pluginInfo ifNotNil: [ :info |
		  info first = self protocol ifFalse: [
			  'the plugin speaks protocol ' , info first printString , ', not ' , self protocol printString ] ]
]

{ #category : 'accessing' }
SimdCSVBackend class >> protocol [
	"SC_PROTOCOL: the protocol of the primitives, which primitiveInfo answers first"

	^ 1
]

{ #category : 'accessing' }
SimdCSVBackend class >> resetBackend [
	"Make the choice of the backend again: ask the plugin"

	| info |
	SessionToken := Smalltalk session.
	CollectedFree := nil.
	info := (self testHook: #pluginMissing) == true ifFalse: [ SimdCSVPrimitives info ].
	info ifNotNil: [
		(self testHook: #protocol) ifNotNil: [ :number |
			info := info copy.
			info at: 1 put: number ] ].
	PluginInfo := info.
	Current := (self testHook: #backend) ifNil: [
		           (info notNil and: [ info first = self protocol ])
			           ifTrue: [ SimdCSVPrimitives ]
			           ifFalse: [ SimdCSVSmalltalk ] ]
]

{ #category : 'private' }
SimdCSVBackend class >> resolve: anAnswer of: aBlock [
	"An answer with a status 0 to 3 for anAnswer, a failure or NO_ROOM of the call that aBlock makes to a backend, or a signal (my class comment)"

	| answer backend grown collected need missing |
	answer := anAnswer.
	backend := self current.
	missing := grown := collected := false.
	[ answer simdCSVFailed or: [ answer first = self statusNoRoom ] ] whileTrue: [
		(answer simdCSVFailed and: [ answer isNotFound and: [ missing not ] ])
			ifTrue: [
				missing := true.
				SessionToken := nil.
				backend := SimdCSVSmalltalk ]
			ifFalse: [
				(answer simdCSVFailed and: [ answer isNoMemory not ]) ifTrue: [ ^ SimdCSVArgumentError signalFailure: answer ].
				collected ifTrue: [ ^ OutOfMemory signal ].
				need := answer simdCSVFailed
					        ifTrue: [ 0 ]
					        ifFalse: [ answer last ].
				(grown or: [ (self grow: need + 1048576) not ]) ifTrue: [
					collected := true.
					Smalltalk garbageCollect ].
				grown := true ].
		answer := aBlock value: backend ].
	^ answer
]

{ #category : 'calls' }
SimdCSVBackend class >> rows: source base: base to: stop dialect: word index: anIndex from: indexFrom to: indexTo types: types fieldCount: fieldCount into: anArray from: destFrom empty: emptyValue budget: budget [
	"{ status. rows. nextIndex. odd. code. position. row. field. need }, with a status 0 to 2"

	| call bytes |
	call := [ :backend :budgetBytes |
	        backend
		        rows: source
		        base: base
		        to: stop
		        dialect: word
		        index: anIndex
		        from: indexFrom
		        to: indexTo
		        types: types
		        fieldCount: fieldCount
		        into: anArray
		        from: destFrom
		        wideStringClass: WideString
		        empty: emptyValue
		        budget: budgetBytes ].
	bytes := budget.
	(self isBounded and: [ self isIndex: anIndex from: indexFrom to: indexTo ]) ifTrue: [
		| last |
		last := self lastSlotIn: source base: base dialect: word index: anIndex from: indexFrom to: indexTo.
		bytes := self
			         budget: budget
			         first: (self boundOf: anIndex from: indexFrom to: last records: 1 fieldCount: fieldCount)
			         all: (self boundOf: anIndex from: indexFrom to: indexTo records: indexTo - indexFrom + 1 fieldCount: fieldCount)
			         for: call ].
	^ self run: [ :backend | call value: backend value: bytes ]
]

{ #category : 'private' }
SimdCSVBackend class >> run: aBlock [
	"The answer of the call that aBlock makes to a backend, with a status 0 to 3"

	| answer |
	answer := aBlock value: self current.
	(answer simdCSVFailed or: [ answer first = self statusNoRoom ]) ifTrue: [ ^ self resolve: answer of: aBlock ].
	^ answer
]

{ #category : 'statuses' }
SimdCSVBackend class >> statusError [
	"SC_ERROR: a code and a position"

	^ 2
]

{ #category : 'statuses' }
SimdCSVBackend class >> statusMore [
	"SC_MORE: no slot left, or the budget used"

	^ 1
]

{ #category : 'statuses' }
SimdCSVBackend class >> statusNoRoom [
	"SC_NO_ROOM: the first record does not fit the object memory; no caller of mine sees it"

	^ 4
]

{ #category : 'statuses' }
SimdCSVBackend class >> statusOK [
	"SC_OK"

	^ 0
]

{ #category : 'statuses' }
SimdCSVBackend class >> statusTooLarge [
	"SC_TOO_LARGE: more than 4,294,967,294 units from the base on"

	^ 3
]

{ #category : 'codes' }
SimdCSVBackend class >> codeBadIndex [
	"SC_E_BAD_INDEX: the index does not fit the source"

	^ 6
]

{ #category : 'codes' }
SimdCSVBackend class >> codeFieldCount [
	"SC_E_FIELD_COUNT: another count of fields"

	^ 5
]

{ #category : 'codes' }
SimdCSVBackend class >> codeInvalidUTF8 [
	"SC_E_INVALID_UTF8"

	^ 4
]

{ #category : 'codes' }
SimdCSVBackend class >> codeTextAfterQuote [
	"SC_E_TEXT_AFTER_QUOTE"

	^ 2
]

{ #category : 'codes' }
SimdCSVBackend class >> codeUnexpectedQuote [
	"SC_E_UNEXPECTED_QUOTE"

	^ 1
]

{ #category : 'codes' }
SimdCSVBackend class >> codeUnterminatedQuote [
	"SC_E_UNTERMINATED_QUOTE"

	^ 3
]

{ #category : 'test hooks' }
SimdCSVBackend class >> testHook: aSymbol [
	"The value of the test hook aSymbol, or nil"

	^ TestHooks ifNotNil: [ :hooks | hooks at: aSymbol ifAbsent: [ nil ] ]
]

{ #category : 'test hooks' }
SimdCSVBackend class >> testHook: aSymbol value: anObject [
	"Set the test hook aSymbol (my class comment) to anObject, nil removing it, and forget the choice of the backend"

	TestHooks ifNil: [ TestHooks := Dictionary new ].
	anObject
		ifNil: [ TestHooks removeKey: aSymbol ifAbsent: [ ] ]
		ifNotNil: [ TestHooks at: aSymbol put: anObject ].
	TestHooks isEmpty ifTrue: [ TestHooks := nil ].
	SessionToken := nil
]
