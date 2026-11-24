"
I compare `SimdCSVReader` with `NeoCSVReader`, and `SimdCSVWriter` with `NeoCSVWriter`, on generated data.
"
Class {
	#name : 'SimdCSVNeoTest',
	#superclass : 'SimdCSVTestCase',
	#category : 'SimdCSV-NeoTests-Tests',
	#package : 'SimdCSV-NeoTests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVNeoTest >> assert: aString read: aBlock [
	"aBlock, of a reader, answers the same for both"

	| neo |
	neo := aBlock value: (NeoCSVReader on: aString readStream).
	self assert: (aBlock value: (SimdCSVReader on: aString readStream)) equals: neo.
	self assert: (aBlock value: (SimdCSVReader on: aString)) equals: neo.
	self assert: (aBlock value: (SimdCSVReader on: aString utf8Encoded)) equals: neo.
	self assert: (aBlock value: (SimdCSVReader on: (ZnCharacterReadStream on: aString utf8Encoded readStream))) equals: neo
]

{ #category : 'helpers' }
SimdCSVNeoTest >> textOf: rows separator: aString [
	"Regular CSV, with every line end"

	| random ends |
	random := self random.
	ends := {
		        String lf.
		        String cr.
		        String crlf }.
	^ String streamContents: [ :out |
		  rows do: [ :row |
			  row
				  do: [ :field |
					  (field anySatisfy: [ :each | each = $" or: [ each = $, or: [ each = $; or: [ each = Character cr or: [ each = Character lf ] ] ] ] ])
						  ifFalse: [
							  (random nextInteger: 4) = 1
								  ifTrue: [ out nextPutAll: '"' , field , '"' ]
								  ifFalse: [ out nextPutAll: field ] ]
						  ifTrue: [
							  out
								  nextPut: $";
								  nextPutAll: (field copyReplaceAll: '"' with: '""');
								  nextPut: $" ] ]
				  separatedBy: [ out nextPutAll: aString ].
			  out nextPutAll: (ends at: (random nextInteger: 3)) ] ]
]

{ #category : 'helpers' }
SimdCSVNeoTest >> randomRows: count width: width [
	"Rectangular; no field of a CR at its end, which an LF could follow; no first field that is empty, for blank lines differ"

	| random |
	random := self random.
	^ (1 to: count) collect: [ :i |
		  (1 to: width) collect: [ :k |
			  (String streamContents: [ :out |
				   (random nextInteger: 12) - 1 timesRepeat: [ out nextPut: ('abcdefgh ,;"' , String cr , 'é' at: (random nextInteger: 14)) ] ]) , (k = 1
				   ifTrue: [ 'x' ]
				   ifFalse: [ #( '' 'y' ) at: (random nextInteger: 2) ]) in: [ :field |
				  (field isEmpty or: [ field last ~= Character cr ])
					  ifTrue: [ field ]
					  ifFalse: [ field , 'z' ] ] ] ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testPlain [
	1 to: 6 do: [ :width | self assertPlainWidth: width ]
]

{ #category : 'helpers' }
SimdCSVNeoTest >> assertPlainWidth: width [
	| rows text header |
	rows := self randomRows: (self largeSize: 300) width: width.
	text := self textOf: rows separator: ','.
	self assert: text read: [ :reader | reader upToEnd ].
	header := (',' join: ((1 to: width) collect: [ :i | 'h' , i printString ])) , String crlf.
	self assert: header , text read: [ :reader | reader readHeader ].
	self assert: header , text read: [ :reader | reader readHeader; next ].
	self assert: text read: [ :reader | reader skipHeader; upToEnd ].
	self assert: text read: [ :reader | reader emptyFieldValue: ''; upToEnd ].
	self assert: text read: [ :reader | reader emptyFieldValue: #passNil; upToEnd ].
	self assert: text read: [ :reader | reader beStrict; upToEnd ].
	self assert: text read: [ :reader | reader skip: 3; next ].
	self assert: text read: [ :reader | reader collect: [ :row | row first ] ].
	self assert: text read: [ :reader | reader select: [ :row | row first size even ] ].
	self assert: text read: [ :reader | reader reject: [ :row | row first size even ] ].
	text := self textOf: rows separator: ';'.
	self assert: text read: [ :reader | reader separator: $;; upToEnd ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testTyped [
	| random text |
	random := self random.
	text := String streamContents: [ :out |
		        out nextPutAll: 'i,f,s,d'; lf.
		        (self largeSize: 500) timesRepeat: [
			        out
				        print: (random nextInteger: 2000000) - 1000000;
				        nextPut: $,;
				        print: (random nextInteger: 100000) / 64.0;
				        nextPutAll: ',"x, y",';
				        nextPutAll: (#( '' 'z' ) at: (random nextInteger: 2));
				        crlf ] ].
	self assert: text read: [ :reader | reader skipHeader; addIntegerField; addFloatField; addSymbolField; addField; upToEnd ].
	self assert: text read: [ :reader | reader skipHeader; addIntegerFields: 1; addFloatFields: 1; addPlainFields: 2; upToEnd ].
	self assert: text read: [ :reader | reader skipHeader; recordClass: Dictionary; addIntegerFieldAt: #i; addFloatFieldAt: #f; addSymbolFieldAt: #s; addFieldAt: #d; upToEnd ].
	self assert: text read: [ :reader | reader skipHeader; recordClass: Dictionary; emptyFieldValue: #passNil; addIntegerFieldAt: #i; addFloatFieldAt: #f; addIgnoredField; addFieldAt: #d converter: [ :each | each ifNil: [ 0 ] ]; upToEnd ].
	self assert: text read: [ :reader | reader skipHeader; addFieldConverter: [ :each | each size ]; addIgnoredFields: 2; addFieldConverter: [ :each | each asUppercase ]; upToEnd ].
	self assert: text read: [ :reader | reader namedColumnsConfiguration; upToEnd ].
	self assert: text read: [ :reader | reader skipHeader; recordClass: OrderedCollection; addFields: { [ :record :value | record add: value ]. [ :record :value | record add: value size ] }; upToEnd ].
	self assert: text read: [ :reader | reader skipHeader; recordClass: Dictionary; addFieldsAt: #( #a #b ); addField: [ :record :value | record at: #c put: value ]; addField: [ :record :value | record at: #d put: value ] converter: [ :each | each size ]; upToEnd ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testShortAndLong [
	| text |
	text := 'a,b,c' , String lf , 'd' , String lf , 'e,f,g,h' , String lf , ',,' , String lf , 'i,'.
	self assert: text read: [ :reader | reader skipHeader; upToEnd ].
	self assert: text read: [ :reader | reader addField; addField; upToEnd ].
	self assert: text read: [ :reader | reader recordClass: Dictionary; addFieldsAt: #( #x #y #z #w ); upToEnd ].
	self assert: text read: [ :reader | reader namedColumnsConfiguration; upToEnd ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testOtherWidths [
	"Without line ends in the fields, over which NeoCSVReader loses its place"

	| rows text |
	rows := (self randomRows: 200 width: 4) collect: [ :row | row collect: [ :each | each copyWithoutAll: { Character cr. Character lf } ] ].
	text := self textOf: rows separator: ','.
	1 to: 8 do: [ :width |
		self assert: text read: [ :reader | reader fieldCount: width; upToEnd ].
		self assert: text read: [ :reader | reader addPlainFields: width; upToEnd ].
		self assert: text read: [ :reader | reader addIgnoredField; addPlainFields: width; upToEnd ] ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testFieldsAfterNext [
	self assert: '1,2' , String cr , '3,4' , String cr , '5,6' read: [ :reader |
		{
			reader next.
			(reader
				 addIntegerField;
				 addField;
				 next).
			reader atEnd.
			reader upToEnd.
			reader atEnd } ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testWriter [
	| rows neo |
	rows := (self randomRows: 100 width: 3) collect: [ :row | row collect: [ :each | each ifEmpty: [ 'e' ] ] ].
	neo := String streamContents: [ :out |
		       (NeoCSVWriter on: out)
			       lineEndConvention: #lf;
			       nextPutAll: rows ].
	self assert: (SimdCSV stringFrom: rows) equals: neo.
	neo := String streamContents: [ :out |
		       (NeoCSVWriter on: out)
			       lineEndConvention: #crlf;
			       separator: $;;
			       fieldWriter: #raw;
			       addFields: { #first. #last };
			       addConstantField: 'k';
			       nextPutAll: #( #( 1 2 ) #( 3 4 ) ) ].
	self
		assert: (String streamContents: [ :out |
				 (SimdCSVWriter on: out)
					 lineEndConvention: #crlf;
					 separator: $;;
					 fieldWriter: #raw;
					 addFields: { #first. #last };
					 addConstantField: 'k';
					 nextPutAll: #( #( 1 2 ) #( 3 4 ) ) ])
		equals: neo
]

{ #category : 'tests' }
SimdCSVNeoTest >> testSelectors [
	"Each selector of NeoCSVReader is implemented, or listed as not provided"

	| own unsupported |
	own := (NeoCSVReader localMethods reject: [ :each | each isExtension ]) collect: [ :each | each selector ].
	unsupported := SimdCSVReader unsupportedNeoSelectors.
	own do: [ :each |
		self
			assert: ((SimdCSVReader includesSelector: each) xor: (unsupported includes: each))
			description: each ].
	unsupported do: [ :each | self assert: (own includes: each) description: each ].
	NeoCSVReader class localSelectors do: [ :each | self assert: (SimdCSVReader class includesSelector: each) description: each ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testWriterSelectors [
	"Each selector of NeoCSVWriter is implemented, or listed as not provided"

	| own unsupported |
	own := (NeoCSVWriter localMethods reject: [ :each | each isExtension ]) collect: [ :each | each selector ].
	unsupported := SimdCSVWriter unsupportedNeoSelectors.
	own do: [ :each |
		self
			assert: ((SimdCSVWriter includesSelector: each) xor: (unsupported includes: each))
			description: each ].
	unsupported do: [ :each | self assert: (own includes: each) description: each ].
	NeoCSVWriter class localSelectors do: [ :each | self assert: (SimdCSVWriter class includesSelector: each) description: each ]
]

{ #category : 'tests' }
SimdCSVNeoTest >> testFieldWriters [
	"The writers of a field write the same"

	| write |
	write := [ :class |
	         String streamContents: [ :out |
		         (class on: out)
			         lineEndConvention: #lf;
			         addQuotedField: #first;
			         addQuotedFields: { #second. #third };
			         addOptionalQuotedField: #first;
			         addOptionalQuotedFields: { #second. #third };
			         addRawField: #third;
			         addRawFields: { #third };
			         addObjectField: #third;
			         addObjectFields: { #third };
			         addQuotedFieldAt: 1;
			         addQuotedFieldsAt: #( 2 3 );
			         addOptionalQuotedFieldAt: 1;
			         addOptionalQuotedFieldsAt: #( 2 3 );
			         addRawFieldAt: 3;
			         addRawFieldsAt: #( 3 );
			         addObjectFieldAt: 3;
			         addObjectFieldsAt: #( 3 );
			         nextPutAll: {
				         #( 'a,b' 'c "d"' 1 ).
				         {
					         'e'.
					         ('f' , String lf , 'g').
					         22 } } ] ].
	self assert: (write value: SimdCSVWriter) equals: (write value: NeoCSVWriter)
]
