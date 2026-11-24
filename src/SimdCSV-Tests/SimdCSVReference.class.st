"
I am the automaton of SimdCSV a second time, written from its definition only and with no thought for speed: the tests compare the backends with me.

`run` makes `events`, in the order of the input:

- `#field`, with the position after its last unit (its end), its text as an Array of units, and whether it was quoted;
- `#record` and `#blank`, with the start of the next record;
- `#bad`, with a code and the position of an irregular unit.

`indexCapacity:base:` folds the events into the answer of an index, whose `entries` I keep.
"
Class {
	#name : 'SimdCSVReference',
	#superclass : 'Object',
	#instVars : [
		'source',
		'from',
		'to',
		'separator',
		'quote',
		'flags',
		'events',
		'state',
		'text',
		'wasQuoted',
		'opening',
		'recordStart',
		'position',
		'afterCR',
		'entries'
	],
	#category : 'SimdCSV-Tests-Support',
	#package : 'SimdCSV-Tests',
	#tag : 'Support'
}

{ #category : 'instance creation' }
SimdCSVReference class >> on: aSource from: start to: stop word: word [
	^ self new
		  setSource: aSource from: start to: stop word: word;
		  run;
		  yourself
]

{ #category : 'instance creation' }
SimdCSVReference class >> on: aSource word: word [
	^ self on: aSource from: 1 to: aSource size word: word
]

{ #category : 'states' }
SimdCSVReference >> afterQuote: unit [
	unit = quote ifTrue: [
		text add: unit.
		^ state := #quoted: ].
	(self isEnd: unit) ifTrue: [ ^ self endField: unit ].
	self bad: 2 at: position.
	text add: unit.
	state := #unquoted:
]

{ #category : 'private' }
SimdCSVReference >> bad: code at: aPosition [
	events add: {
			#bad.
			code.
			aPosition }
]

{ #category : 'private' }
SimdCSVReference >> endData [
	"The end of the data, or of the part of them there is"

	(self has: #Final) ifFalse: [
		"a CR there may go on with an LF: its record or blank line is not complete"
		(afterCR and: [ position = (to + 1) ]) ifTrue: [ events removeLast ].
		^ self ].
	state == #quoted: ifTrue: [ self bad: 3 at: opening ].
	recordStart <= to ifTrue: [
		self fieldEnd.
		self record ]
]

{ #category : 'private' }
SimdCSVReference >> endField: unit [
	"The unit ends a field, and its record unless it is the separator"

	| isBlank |
	isBlank := (self has: #SkipBlank) and: [ position = recordStart and: [ unit ~= separator ] ].
	isBlank ifFalse: [ self fieldEnd ].
	unit = separator ifTrue: [ ^ self ].
	recordStart := position + 1.
	isBlank
		ifTrue: [
			events add: {
					#blank.
					recordStart } ]
		ifFalse: [ self record ].
	afterCR := unit = 13
]

{ #category : 'accessing' }
SimdCSVReference >> entries [
	"The entries of the last index"

	^ entries
]

{ #category : 'private' }
SimdCSVReference >> fieldEnd [
	events add: {
			#field.
			position.
			text asArray.
			wasQuoted }.
	text := OrderedCollection new.
	wasQuoted := false.
	state := #start:
]

{ #category : 'private' }
SimdCSVReference >> has: aSymbol [
	^ (flags bitAnd: (SimdCSVDialect perform: ('flag' , aSymbol) asSymbol)) ~= 0
]

{ #category : 'accessing' }
SimdCSVReference >> indexCapacity: capacity base: base [
	"The answer of an index of capacity slots from base on"

	| status code where stored records next min max open |
	status := code := where := records := min := max := 0.
	next := from.
	stored := OrderedCollection new.
	open := OrderedCollection new.
	events do: [ :event |
		status = 0 ifTrue: [
			event first == #field ifTrue: [
				stored size + open size = capacity
					ifTrue: [ status := 1 ]
					ifFalse: [ open add: event second - base ] ].
			event first == #record ifTrue: [
				stored addAll: open.
				records := records + 1.
				min := records = 1
					       ifTrue: [ open size ]
					       ifFalse: [ min min: open size ].
				max := max max: open size.
				open := OrderedCollection new.
				next := event second ].
			event first == #blank ifTrue: [ next := event second ].
			(event first == #bad and: [ self has: #Strict ]) ifTrue: [
				status := 2.
				code := event second.
				where := event third ] ] ].
	entries := stored asArray.
	^ {
		  status.
		  stored size.
		  records.
		  next.
		  (self linesTo: next).
		  min.
		  max.
		  code.
		  where }
]

{ #category : 'private' }
SimdCSVReference >> isEnd: unit [
	^ unit = separator or: [ self isLineEnd: unit ]
]

{ #category : 'private' }
SimdCSVReference >> isLineEnd: unit [
	^ unit = 10 or: [ unit = 13 and: [ (self has: #LfOnly) not ] ]
]

{ #category : 'private' }
SimdCSVReference >> linesTo: next [
	"The line ends before next"

	| part |
	(self has: #Lines) ifFalse: [ ^ 0 ].
	part := (from to: next - 1) collect: [ :i | source basicAt: i ].
	(self has: #LfOnly) ifTrue: [ ^ part occurrencesOf: 10 ].
	^ (part occurrencesOf: 10) + (part occurrencesOf: 13)
	  - ((1 to: part size - 1) count: [ :i | (part at: i) = 13 and: [ (part at: i + 1) = 10 ] ])
]

{ #category : 'states' }
SimdCSVReference >> quoted: unit [
	unit = quote ifTrue: [ ^ state := #afterQuote: ].
	text add: unit
]

{ #category : 'private' }
SimdCSVReference >> record [
	recordStart := position + 1 min: to + 1.
	events add: {
			#record.
			recordStart }
]

{ #category : 'accessing' }
SimdCSVReference >> records [
	"The complete records, Arrays of the units of their fields"

	| records fields |
	records := OrderedCollection new.
	fields := OrderedCollection new.
	events do: [ :event |
		event first == #field ifTrue: [ fields add: event third ].
		event first == #record ifTrue: [
			records add: fields asArray.
			fields := OrderedCollection new ] ].
	^ records asArray
]

{ #category : 'running' }
SimdCSVReference >> run [
	events := OrderedCollection new.
	text := OrderedCollection new.
	wasQuoted := afterCR := false.
	state := #start:.
	recordStart := from.
	position := from.
	[ position <= to ] whileTrue: [
		| unit |
		unit := source basicAt: position.
		(afterCR and: [ unit = 10 ])
			ifTrue: [
				"it belongs to the CR that ended the last record or blank line"
				afterCR := false.
				recordStart := position + 1.
				events last at: 2 put: recordStart ]
			ifFalse: [
				afterCR := false.
				self perform: state with: unit ].
		position := position + 1 ].
	self endData
]

{ #category : 'initialization' }
SimdCSVReference >> setSource: aSource from: start to: stop word: word [
	source := aSource.
	from := start.
	to := stop.
	separator := word bitAnd: 16r1FFFFF.
	flags := word bitShift: -29.
	quote := (self has: #NoQuote) ifFalse: [ (word bitShift: -21) bitAnd: 255 ]
]

{ #category : 'states' }
SimdCSVReference >> start: unit [
	unit = quote ifTrue: [
		wasQuoted := true.
		opening := position.
		^ state := #quoted: ].
	(self isEnd: unit) ifTrue: [ ^ self endField: unit ].
	text add: unit.
	state := #unquoted:
]

{ #category : 'states' }
SimdCSVReference >> unquoted: unit [
	(self isEnd: unit) ifTrue: [ ^ self endField: unit ].
	unit = quote ifTrue: [ self bad: 1 at: position ].
	text add: unit
]
