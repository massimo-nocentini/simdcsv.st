"
I test that records, the errors in their place and the work that is done for them come in the order of the text: errors at the first, a middle and the last record of a batch, repeated and passed, conversions that are resumed, and configurations that change.
"
Class {
	#name : 'SimdCSVDeliveryTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVDeliveryTest >> batchSizes [
	"In one batch, and in many"

	^ #( 1048576 1 7 64 )
]

{ #category : 'helpers' }
SimdCSVDeliveryTest >> assertFailing: aString at: bad of: total class: aClass with: aBlock [
	"The reader of aString, configured by aBlock, answers the records before the one numbered bad, fails there with aClass again and again, and after skipFailedRecord answers the others"

	self batchSizes do: [ :size |
		self sourcesOf: aString do: [ :source :name |
			| reader numbers |
			reader := self reader: source.
			reader batchBytes: size.
			aBlock value: reader.
			numbers := OrderedCollection new.
			self assert: [ reader do: [ :row | numbers add: row first asInteger ] ] signals: aClass.
			self assert: numbers asArray equals: (1 to: bad - 1) asArray.
			self deny: reader atEnd.
			self assert: reader recordNumber equals: bad - 1.
			3 timesRepeat: [ self assert: [ reader next ] signals: aClass ].
			reader skipFailedRecord.
			self assert: reader recordNumber equals: bad.
			reader do: [ :row | numbers add: row first asInteger ].
			self assert: numbers asArray equals: ((1 to: total) reject: [ :each | each = bad ]).
			reader skipFailedRecord.
			self assert: reader recordNumber equals: total ] ]
]

{ #category : 'helpers' }
SimdCSVDeliveryTest >> numbered: total with: aString at: bad [
	"The lines 'n,n', but aString for the one numbered bad, and a quoted line end here and there"

	^ String streamContents: [ :out |
		  1 to: total do: [ :i |
			  out nextPutAll: (i = bad
					   ifTrue: [ aString ]
					   ifFalse: [
						   i \\ 3 = 0
							   ifTrue: [ i printString , ',"' , i printString , '"' ]
							   ifFalse: [ i printString , ',' , i printString ] ]).
			  i = total ifFalse: [ out lf ] ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testQuoteErrorAtEveryRecord [
	#( 1 2 5 9 10 ) do: [ :bad |
		self assertFailing: (self numbered: 10 with: '7,x"y' at: bad) at: bad of: 10 class: SimdCSVQuoteError with: [ :reader | reader beStrictQuoting ].
		self assertFailing: (self numbered: 10 with: '"7"z,"x' , String lf , 'y"' at: bad) at: bad of: 10 class: SimdCSVQuoteError with: [ :reader | reader beStrictQuoting ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testMismatchAtEveryRecord [
	#( 1 2 5 9 10 ) do: [ :bad | self assertFailing: (self numbered: 10 with: '1,2,"3' , String lf , '"' at: bad) at: bad of: 10 class: SimdCSVFieldCountMismatch with: [ :reader | reader beStrict; fieldCount: 2 ] ].
	#( 2 5 9 10 ) do: [ :bad | self assertFailing: (self numbered: 10 with: '1' at: bad) at: bad of: 10 class: SimdCSVFieldCountMismatch with: [ :reader | reader beStrict ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testConversionErrorAtEveryRecord [
	#( 1 2 5 9 10 ) do: [ :bad | self assertFailing: (self numbered: 10 with: '1,x' at: bad) at: bad of: 10 class: SimdCSVConversionError with: [ :reader | reader addIntegerField; addIntegerField ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testEncodingErrorAtEveryRecord [
	#( 1 2 5 9 10 ) do: [ :bad |
		| bytes reader numbers |
		bytes := (self numbered: 10 with: '1,#' at: bad) asByteArray.
		bytes at: (bytes indexOf: $# asInteger) put: 255.
		self batchSizes do: [ :size |
			reader := self reader: bytes.
			reader batchBytes: size.
			numbers := OrderedCollection new.
			[ reader atEnd ] whileFalse: [
				[ numbers add: reader next first asInteger ]
					on: SimdCSVInvalidEncoding
					do: [
						self assert: [ reader next ] signals: SimdCSVInvalidEncoding.
						reader skipFailedRecord ] ].
			self assert: numbers asArray equals: ((1 to: 10) reject: [ :each | each = bad ]) ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testErrorsOfSeveralKinds [
	"In the order of the records, also where the index and the builder see them in another one"

	| text reader seen |
	text := self lines: #( '1,1' 'x,1' '2,1,1' '3,3' '4"4,1' 'y,2' '5,5' '6,"6"6' '7,7,7' '8,8' ).
	self batchSizes do: [ :size |
		reader := self reader: text.
		reader batchBytes: size; beStrict; beStrictQuoting; addIntegerField; addIntegerField.
		seen := OrderedCollection new.
		[ reader atEnd ] whileFalse: [
			[ seen add: reader next first ]
				on: SimdCSVError
				do: [ :error |
					seen add: error class.
					reader skipFailedRecord ] ].
		self assert: seen asArray equals: { 1. SimdCSVConversionError. SimdCSVFieldCountMismatch. 3. SimdCSVQuoteError. SimdCSVConversionError. 5. SimdCSVQuoteError. SimdCSVFieldCountMismatch. 8 } ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testSkipPassesWhatIsNotRead [
	"But not a record whose end is not known"

	| reader |
	reader := self reader: (self lines: #( 'x' '1,2,3' '4' '5"' '6' )).
	reader beStrict; beStrictQuoting; addIntegerField.
	reader skip: 2.
	self assert: reader next equals: #( 4 ).
	self assert: [ reader skip ] signals: SimdCSVQuoteError.
	reader skipFailedRecord.
	self assert: reader next equals: #( 6 ).
	self assert: ((self reader: #[ 255 10 97 ]) skip; next) equals: #( 'a' )
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testSkipFailedRecordWithoutFailure [
	| reader |
	reader := self reader: (self lines: #( 'a' 'b' )).
	reader skipFailedRecord.
	self assert: reader next equals: #( 'a' ).
	reader skipFailedRecord.
	self assert: reader next equals: #( 'b' ).
	reader skipFailedRecord.
	self assert: reader atEnd
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testUnclosedQuoteIsPassedToTheEnd [
	| reader |
	self batchSizes do: [ :size |
		reader := self reader: (self lines: #( '1' '"2' '3' '4' )).
		reader batchBytes: size; beStrictQuoting.
		self assert: reader next equals: #( '1' ).
		self assert: (self assert: [ reader next ] signals: SimdCSVQuoteError) code equals: 3.
		reader skipFailedRecord.
		self assert: reader atEnd.
		self assert: reader next isNil ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testResourceErrorIsPassedToTheEnd [
	| reader |
	#( 1 4 1048576 ) do: [ :size |
		self sourcesOf: (self lines: #( '1' '2' '345678901234567890' '4' )) do: [ :source :name |
			reader := self reader: source.
			reader batchBytes: size; maxRecordBytes: 12.
			self assert: reader next equals: #( '1' ).
			self assert: reader next equals: #( '2' ).
			2 timesRepeat: [ self assert: [ reader next ] signals: SimdCSVResourceError ].
			reader skipFailedRecord.
			self assert: reader atEnd.
			self assert: reader upToEnd equals: #(  ) ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testChangedSource [
	"A source that is changed between two batches is no more than an error, which is not passed but to the next record of the index"

	| bytes reader |
	bytes := (self lines: ((1 to: 5000) collect: [ :i | i printString ])) asByteArray.
	reader := self reader: bytes.
	reader skip: 4000.
	bytes replaceFrom: 1 to: bytes size with: (ByteArray new: bytes size withAll: 97) startingAt: 1.
	reader skip: 96.
	2 timesRepeat: [ self assert: [ reader next ] signals: SimdCSVArgumentError text: 'The source was changed while it was read' ].
	self deny: reader atEnd.
	bytes := (self lines: #( 'a' 'b' )) asByteArray.
	self assert: [
		(SimdCSVTable on: bytes) in: [ :table |
			bytes replaceFrom: 1 to: 4 with: #[ 97 97 97 97 ] startingAt: 1.
			table rowAt: 1 ] ] signals: SimdCSVArgumentError
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testQuoteErrorInLongRecord [
	"A record whose end is beyond the limit is passed to the end of the input"

	| text reader |
	text := '1' , String lf , '2"' , (String new: 100 withAll: $x) , String lf , '3'.
	{ text. SimdCSVTestStream on: text asByteArray sizes: #( 9 ) } do: [ :source |
		reader := self reader: source.
		reader
			batchBytes: 10;
			maxRecordBytes: 20;
			beStrictQuoting.
		self assert: reader next equals: #( '1' ).
		self assert: [ reader next ] signals: SimdCSVQuoteError.
		reader skipFailedRecord.
		self assert: reader atEnd ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testHeaderAfterError [
	"The errors that stand before a record are those of the header too"

	| reader |
	reader := self reader: (self lines: #( 'a"' 'b' )).
	reader beStrictQuoting.
	2 timesRepeat: [ self assert: [ reader readHeader ] signals: SimdCSVQuoteError ].
	self assert: [ reader next ] signals: SimdCSVQuoteError.
	reader skipFailedRecord.
	self assert: reader readHeader equals: #( 'b' ).
	reader := self reader: #[ 255 10 97 10 98 ].
	2 timesRepeat: [ self assert: [ reader readHeader ] signals: SimdCSVInvalidEncoding ].
	reader skipFailedRecord.
	self assert: reader readHeader equals: #( 'a' ).
	self assert: reader upToEnd equals: #( #( 'b' ) )
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testLimitRaisedAfterError [
	self sourcesOf: (self lines: #( '1' '345678901234567890' '4' )) do: [ :source :name |
		| reader |
		reader := self reader: source.
		reader maxRecordBytes: 12.
		self assert: reader next equals: #( '1' ).
		self assert: [ reader next ] signals: SimdCSVResourceError.
		reader maxRecordBytes: 100.
		self assert: reader upToEnd equals: #( #( '345678901234567890' ) #( '4' ) ) ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testTooManyFields [
	| reader |
	reader := self reader: '1' , String lf , (String new: 1024 withAll: $,) , String lf , '2' , String lf , (String new: 1023 withAll: $,).
	reader maxFields: 1024.
	self assert: reader next equals: #( '1' ).
	2 timesRepeat: [ self assert: (self assert: [ reader next ] signals: SimdCSVResourceError) kind equals: #fields ].
	reader skipFailedRecord.
	self assert: reader atEnd.
	self assert: ((self reader: (String new: 1023 withAll: $,)) maxFields: 1024; next) size equals: 1024
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testResume [
	| rows |
	rows := [ (self reader: (self lines: #( '1,a' 'x,2.5' '3,nan' ))) addIntegerField; addFloatField; upToEnd ]
		        on: SimdCSVConversionError
		        do: [ :error | error resume: error text size negated ].
	self assert: (rows first: 2) equals: #( #( 1 -1 ) #( -1 2.5 ) ).
	rows := [ (self reader: (self lines: #( 'x' '7' ))) recordClass: Dictionary; addIntegerFieldAt: #n; upToEnd ]
		        on: SimdCSVConversionError
		        do: [ :error | error resume: nil ].
	self assert: rows equals: { ({ (#n -> nil) } asDictionary). ({ (#n -> 7) } asDictionary) }
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testResumeOnlyOnce [
	"A record that was made is passed"

	| reader count |
	reader := self reader: (self lines: #( 'x' '7' )).
	reader addIntegerField.
	count := 0.
	[ self assert: reader next equals: #( 0 ) ]
		on: SimdCSVConversionError
		do: [ :error |
			count := count + 1.
			error resume: 0 ].
	self assert: count equals: 1.
	self assert: reader next equals: #( 7 )
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testErrorOfConverter [
	"Any error of a converter or an accessor leaves me on the record; what was converted is not converted twice"

	| reader fail |
	fail := true.
	reader := self reader: (self lines: #( 'a,b' 'c,d' )).
	reader
		addFieldConverter: [ :each | each , each ];
		addFieldConverter: [ :each |
			fail ifTrue: [ 1 / 0 ].
			each ].
	2 timesRepeat: [ self should: [ reader next ] raise: ZeroDivide ].
	fail := false.
	self assert: reader next equals: #( 'aa' 'b' ).
	fail := true.
	self should: [ reader next ] raise: ZeroDivide.
	reader skipFailedRecord.
	self assert: reader atEnd.
	reader := self reader: (self lines: #( 'a' 'b' )).
	reader recordClass: SimdCSVTestRecord; addField: [ :record :value | value = 'a' ifTrue: [ 1 / 0 ] ].
	self should: [ reader next ] raise: ZeroDivide.
	reader skipFailedRecord.
	self assert: reader next equals: SimdCSVTestRecord new
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testNothingIsConvertedAhead [
	| log reader |
	log := OrderedCollection new.
	reader := self reader: (self lines: #( 'a' 'b' 'c' )).
	reader addFieldConverter: [ :each |
		log add: each asUppercase.
		each ].
	self deny: reader atEnd.
	self assert: log isEmpty.
	reader do: [ :row | log add: row first ].
	self assert: log asArray equals: #( 'A' 'a' 'B' 'b' 'C' 'c' )
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testInvalidIsReachedInOrder [
	"A conversion error is signalled after the block was called for the records before it"

	| log reader |
	log := OrderedCollection new.
	reader := self reader: (self lines: #( '1' '2' 'x' '4' )).
	reader addIntegerField.
	self assert: [ reader do: [ :row | log add: row first ] ] signals: SimdCSVConversionError.
	self assert: log asArray equals: #( 1 2 )
]

{ #category : 'helpers' }
SimdCSVDeliveryTest >> firstEvenIn: aReader [
	aReader do: [ :row | row first asInteger even ifTrue: [ ^ row first ] ].
	^ nil
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testNonLocalReturn [
	| reader |
	self batchSizes do: [ :size |
		reader := self reader: (self lines: #( '1' '2' '3' '4' '5' )).
		reader batchBytes: size.
		self assert: (self firstEvenIn: reader) equals: '2'.
		self assert: reader recordNumber equals: 2.
		self assert: reader next equals: #( '3' ).
		self assert: (self firstEvenIn: reader) equals: '4'.
		self assert: (self firstEvenIn: reader) isNil ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testErrorInDo [
	"The record was passed when the block was called"

	| reader |
	reader := self reader: (self lines: #( '1' '2' '3' )).
	self should: [ reader do: [ :row | row first = '2' ifTrue: [ 1 / 0 ] ] ] raise: ZeroDivide.
	self assert: reader next equals: #( '3' )
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testConfigurationAfterNext [
	| text |
	text := self lines: #( '1,"",3' '4,"",6' '7,"",9' 'a,"",c' ).
	self batchSizes do: [ :size |
		self sourcesOf: text do: [ :source :name |
			| reader |
			reader := self reader: source.
			reader batchBytes: size.
			self assert: reader next equals: { '1'. nil. '3' }.
			reader keepQuotedEmpty.
			self assert: reader next equals: #( '4' '' '6' ).
			reader addIntegerField; addIgnoredField; addIntegerField.
			self assert: reader next equals: #( 7 9 ).
			self assert: [ reader next ] signals: SimdCSVConversionError.
			reader ifInvalid: [ :each :record :field |
				{
					each.
					record.
					field } ].
			self assert: reader next equals: #( #( 'a' 4 1 ) #( 'c' 4 3 ) ).
			self assert: reader atEnd ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testWidthAfterNext [
	| reader |
	reader := self reader: (self lines: #( 'a' 'b,c' 'd,e' 'f,g,h' 'i' )).
	self assert: reader next equals: #( 'a' ).
	reader fieldCount: 1.
	self assert: reader next equals: #( 'b' ).
	reader fieldCount: nil; beStrict.
	self assert: reader next equals: #( 'd' 'e' ).
	self assert: [ reader next ] signals: SimdCSVFieldCountMismatch.
	reader fieldCount: 3.
	self assert: reader next equals: #( 'f' 'g' 'h' ).
	self assert: [ reader next ] signals: SimdCSVFieldCountMismatch
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testBeStrictIsOfTheFirstRecordAfterwards [
	"A configuration before the first strict record was answered does not fix the width"

	| reader |
	reader := self reader: (self lines: #( 'a' 'b,c' 'd,e' )).
	reader beStrict.
	self deny: reader atEnd.
	reader skip.
	self deny: reader atEnd.
	reader emptyFieldValue: ''.
	self assert: reader upToEnd equals: #( #( 'b' 'c' ) #( 'd' 'e' ) )
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testDialectAfterNext [
	"What is not delivered is indexed again, from the start of the next record"

	| text |
	text := 'a,b' , String crlf , 'c;d,e' , String crlf , '"f;g";h' , String lf , '''i;j'';"k' , String lf , 'l' , String lf , String lf , 'm"'.
	self batchSizes do: [ :size |
		self sourcesOf: text do: [ :source :name |
			| reader |
			reader := self reader: source.
			reader batchBytes: size.
			self assert: reader next equals: #( 'a' 'b' ).
			reader separator: $;.
			self assert: reader next equals: #( 'c' 'd,e' ).
			self assert: reader next equals: #( 'f;g' 'h' ).
			reader quote: $'.
			self assert: reader next equals: #( 'i;j' '"k' ).
			reader skipEmptyLines.
			self assert: reader next equals: #( 'l' ).
			self assert: reader next equals: #( 'm"' ).
			self assert: reader atEnd ] ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testStrictQuotingAfterNext [
	| reader |
	self batchSizes do: [ :size |
		reader := self reader: (self lines: #( 'a"' 'b"' 'c' )).
		reader batchBytes: size.
		self assert: reader next equals: #( 'a"' ).
		self deny: reader atEnd.
		reader beStrictQuoting.
		self assert: [ reader next ] signals: SimdCSVQuoteError.
		reader dialect: SimdCSVDialect comma.
		self assert: reader next equals: #( 'b"' ).
		self assert: reader next equals: #( 'c' ).
		self assert: reader atEnd ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testRecordNumberOverChanges [
	| reader |
	reader := self reader: (self lines: #( 'h,i' '1,1' '2,2' '3,3' '4,4' )).
	reader readHeader.
	reader next.
	self assert: reader recordNumber equals: 2.
	reader separator: $,.
	self assert: reader recordNumber equals: 2.
	reader next.
	reader addField.
	self assert: reader recordNumber equals: 3.
	reader skip.
	self assert: reader recordNumber equals: 4.
	reader do: [ :row | self assert: reader recordNumber equals: 5 ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testRandomChanges [
	"The records that a reader answers do not depend on harmless configuration messages between them"

	| random |
	random := self random.
	(self largeSize: 100) timesRepeat: [
		| text expected reader rows |
		text := String streamContents: [ :out |
			        (random nextInteger: 60) timesRepeat: [ out nextPut: ('abc,,"' , String crlf , String lf at: (random nextInteger: 9)) ] ].
		expected := self read: text.
		reader := self reader: ((random nextInteger: 2) = 1
				           ifTrue: [ text ]
				           ifFalse: [ SimdCSVTestStream on: text asByteArray sizes: { (random nextInteger: 5). (random nextInteger: 9) } ]).
		reader batchBytes: (random nextInteger: 30).
		rows := OrderedCollection new.
		[ reader atEnd ] whileFalse: [
			(random nextInteger: 5) caseOf: {
					([ 1 ] -> [ reader separator: $, ]).
					([ 2 ] -> [ reader emptyFieldValue: nil ]).
					([ 3 ] -> [ reader batchBytes: (random nextInteger: 30) ]).
					([ 4 ] -> [ reader dialect: reader dialect ]).
					([ 5 ] -> [ reader maxFields: 1023 + (random nextInteger: 10) ]) }.
			rows add: reader next ].
		self assert: rows asArray equals: expected ]
]

{ #category : 'tests' }
SimdCSVDeliveryTest >> testErrorOfStreamIsNotTheEnd [
	"A read that fails can be tried again"

	| stream reader |
	1 to: 8 do: [ :read |
		stream := SimdCSVTestStream on: (self lines: #( 'a,b' 'c,d' 'e,f' )) asByteArray sizes: #( 3 ).
		stream failAt: read.
		reader := self reader: stream.
		self
			assert: (Array streamContents: [ :out |
					 [ [ reader atEnd ] on: Error do: [ :error | error retry ] ] whileFalse: [ out nextPut: reader next ] ])
			equals: #( #( 'a' 'b' ) #( 'c' 'd' ) #( 'e' 'f' ) ) ]
]
