"
I write records as CSV to a stream of characters, or to a binary stream as UTF-8 (in the `encoding:` of my dialect).

```smalltalk
String streamContents: [ :stream |
	(SimdCSVWriter on: stream)
		fieldWriter: #optionalQuoted;
		writeHeader: #( 'id' 'name' );
		addField: #id;
		addField: [ :each | each name ];
		nextPutAll: people ]
```

I have the protocol of `NeoCSVWriter`. Without fields declared, a record is what `do:` of the object gives.

## Fields

| object | text |
|---|---|
| `emptyFieldValue` (nil) | none: an unquoted empty field |
| String, Symbol | itself |
| Float | its shortest decimal text; `nan`, `inf`, `-inf` |
| Fraction | that of `asFloat` |
| ScaledDecimal | its decimal digits |
| another object | `asString` |

- `fieldWriter: #quoted` (the default) puts quotes around each text; an empty String is an empty quoted field.
- `#optionalQuoted` does so only where it is needed: for a separator, a quote or a line end in the text, for an empty String, and for a first field of the output that begins with U+FEFF, which would be a byte order mark.
- `#raw` never does, and refuses (`SimdCSVArgumentError`) a text that would not read back; `beUnchecked` writes it nevertheless. It is the only one, and the default, for a dialect without a quote.

A record of one empty field is written as an empty quoted field, as a blank line may be none; with `keepQuotedEmpty: true` it is a blank line. A record without fields is refused. Nothing of a record that is refused is written.

## Reading back

Records of at least one field, each nil or a String that is not empty, are read back equal with the same dialect from `#quoted` and from `#optionalQuoted`. With `keepQuotedEmpty: true` empty Strings are too.

Lines end with LF, or as `lineEndConvention:` says (`#lf`, `#crlf`, `#cr`).
"
Class {
	#name : 'SimdCSVWriter',
	#superclass : 'Object',
	#instVars : [
		'stream',
		'isBinary',
		'dialect',
		'lineEnd',
		'fieldWriter',
		'fields',
		'unchecked',
		'checked',
		'atStart',
		'buffer',
		'fieldsDone'
	],
	#category : 'SimdCSV-Writing',
	#package : 'SimdCSV',
	#tag : 'Writing'
}

{ #category : 'instance creation' }
SimdCSVWriter class >> on: aStream [
	^ self new
		  on: aStream;
		  yourself
]

{ #category : 'initialization' }
SimdCSVWriter >> initialize [
	super initialize.
	dialect := SimdCSVDialect comma.
	lineEnd := String lf.
	unchecked := checked := false.
	atStart := true.
	buffer := (String new: 256) writeStream
]

{ #category : 'initialization' }
SimdCSVWriter >> on: aStream [
	stream := aStream.
	isBinary := (aStream respondsTo: #isBinary) and: [ aStream isBinary ]
]

{ #category : 'configuration' }
SimdCSVWriter >> dialect: aDialect [
	"Write as aDialect says, which I copy"

	dialect := aDialect copy.
	checked := false
]

{ #category : 'configuration' }
SimdCSVWriter >> separator: aCharacter [
	"The Character between the fields, a comma by default"

	dialect separator: aCharacter.
	checked := false
]

{ #category : 'configuration' }
SimdCSVWriter >> quote: aCharacterOrNil [
	"The Character around quoted fields, a double quote by default, or nil when there are none"

	dialect quote: aCharacterOrNil.
	checked := false
]

{ #category : 'configuration' }
SimdCSVWriter >> emptyFieldValue: anObject [
	"What is an empty field, nil by default"

	dialect emptyFieldValue: anObject
]

{ #category : 'configuration' }
SimdCSVWriter >> lineEndConvention: aSymbol [
	"#lf, the default, #crlf or #cr"

	(#( #lf #crlf #cr ) includes: aSymbol) ifFalse: [ ^ SimdCSVArgumentError signal: 'The line end is #lf, #crlf or #cr, not ' , aSymbol printString ].
	lineEnd := String perform: aSymbol.
	checked := false
]

{ #category : 'configuration' }
SimdCSVWriter >> fieldWriter: aSymbol [
	"#quoted, #optionalQuoted or #raw"

	(#( #quoted #optionalQuoted #raw ) includes: aSymbol) ifFalse: [
		^ SimdCSVArgumentError signal: 'The field writer is #quoted, #optionalQuoted or #raw, not ' , aSymbol printString ].
	fieldWriter := aSymbol.
	checked := false
]

{ #category : 'configuration' }
SimdCSVWriter >> beUnchecked [
	"Write what would not read back"

	unchecked := true
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> addField: accessor [
	"A field, the value of accessor (a Symbol or a block) for the object"

	self addFieldBlock: [ :object | accessor value: object ]
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> addFields: accessors [
	accessors do: [ :each | self addField: each ]
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> addFieldAt: key [
	"A field, what the object has at key, empty when it has nothing"

	self addFieldBlock: [ :object | object at: key ifAbsent: [ dialect emptyFieldValue ] ]
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> addFieldsAt: keys [
	keys do: [ :each | self addFieldAt: each ]
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> addConstantField: anObject [
	self addFieldBlock: [ :object | anObject ]
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> addEmptyField [
	self addFieldBlock: [ :object | dialect emptyFieldValue ]
]

{ #category : 'configuration - fields' }
SimdCSVWriter >> namedColumnsConfiguration: names [
	"Write the header, then objects that answer at:ifAbsent: of the names, such as Dictionaries"

	self
		writeHeader: names;
		addFieldsAt: names
]

{ #category : 'writing' }
SimdCSVWriter >> writeHeader: names [
	"A record of the names, whatever the fields are"

	self begin.
	names do: [ :each | self put: each ].
	self end
]

{ #category : 'writing' }
SimdCSVWriter >> nextPut: anObject [
	"A record: the declared fields of anObject, else its elements"

	self begin.
	fields
		ifNil: [ anObject do: [ :each | self put: each ] ]
		ifNotNil: [ fields do: [ :each | self put: (each value: anObject) ] ].
	self end
]

{ #category : 'writing' }
SimdCSVWriter >> nextPutAll: aCollection [
	"A record for each"

	aCollection do: [ :each | self nextPut: each ]
]

{ #category : 'writing' }
SimdCSVWriter >> flush [
	stream flush
]

{ #category : 'writing' }
SimdCSVWriter >> close [
	stream ifNotNil: [ stream close ].
	stream := nil
]

{ #category : 'private' }
SimdCSVWriter >> addFieldBlock: aBlock [
	fields := fields
		          ifNil: [ { aBlock } ]
		          ifNotNil: [ fields copyWith: aBlock ]
]

{ #category : 'private' }
SimdCSVWriter >> writerKind [
	^ fieldWriter ifNil: [
		  dialect quote
			  ifNil: [ #raw ]
			  ifNotNil: [ #quoted ] ]
]

{ #category : 'private' }
SimdCSVWriter >> check [
	"Can what I write be read with the dialect?"

	checked ifTrue: [ ^ self ].
	dialect
		wordFor: (isBinary
				 ifTrue: [ #[  ] ]
				 ifFalse: [ WideString new ])
		final: false
		lines: false
		exact: false.
	(dialect quote isNil and: [ self writerKind ~~ #raw ]) ifTrue: [ self refuse: 'A dialect without a quote needs the field writer #raw' ].
	(dialect lineEnd == #lf and: [ lineEnd ~= String lf and: [ unchecked not ] ]) ifTrue: [ self refuse: 'The records of the dialect end with LF only' ].
	checked := true
]

{ #category : 'private' }
SimdCSVWriter >> refuse: aString [
	^ SimdCSVArgumentError signal: aString
]

{ #category : 'private' }
SimdCSVWriter >> begin [
	self check.
	buffer reset.
	fieldsDone := 0
]

{ #category : 'private' }
SimdCSVWriter >> end [
	"Write the record that is in the buffer"

	| text |
	fieldsDone = 0 ifTrue: [ ^ self refuse: 'A record has at least one field' ].
	(fieldsDone = 1 and: [ buffer position = 0 ]) ifTrue: [ self putOnlyEmptyField ].
	buffer nextPutAll: lineEnd.
	text := buffer contents.
	stream nextPutAll: (isBinary
			 ifTrue: [ self encode: text ]
			 ifFalse: [ text ]).
	atStart := false.
	text isWideString ifTrue: [ buffer := (String new: 256) writeStream ]
]

{ #category : 'private' }
SimdCSVWriter >> putOnlyEmptyField [
	"A record of one empty field"

	(dialect quote notNil and: [ dialect keepQuotedEmpty not ]) ifTrue: [
		^ buffer
			  nextPut: dialect quote;
			  nextPut: dialect quote ].
	(dialect skipEmptyLines and: [ unchecked not ]) ifTrue: [ self refuse: 'A record of one empty field is a blank line, which the dialect skips' ]
]

{ #category : 'private' }
SimdCSVWriter >> encode: aString [
	dialect encoding == #utf8 ifTrue: [ ^ aString utf8Encoded ].
	(aString allSatisfy: [ :each | each asInteger < 256 ]) ifFalse: [ ^ self refuse: 'A character is not in Latin-1' ].
	^ aString asByteString asByteArray
]

{ #category : 'private' }
SimdCSVWriter >> put: anObject [
	"The next field of the record"

	fieldsDone > 0 ifTrue: [ buffer nextPut: dialect separator ].
	fieldsDone := fieldsDone + 1.
	anObject = dialect emptyFieldValue ifTrue: [ ^ self ].
	self putText: (self textOf: anObject)
]

{ #category : 'private' }
SimdCSVWriter >> putText: aString [
	| kind |
	kind := self writerKind.
	kind == #quoted ifTrue: [ ^ self putQuoted: aString ].
	kind == #raw ifTrue: [
		(unchecked or: [ self isReadBack: aString ]) ifFalse: [ ^ self refuse: 'The text would not read back without quotes: ' , aString printString ].
		^ buffer nextPutAll: aString ].
	(self needsQuotes: aString)
		ifTrue: [ self putQuoted: aString ]
		ifFalse: [ buffer nextPutAll: aString ]
]

{ #category : 'private' }
SimdCSVWriter >> putQuoted: aString [
	| quote |
	quote := dialect quote.
	buffer nextPut: quote.
	(aString includes: quote)
		ifFalse: [ buffer nextPutAll: aString ]
		ifTrue: [
			aString do: [ :each |
				each = quote ifTrue: [ buffer nextPut: quote ].
				buffer nextPut: each ] ].
	buffer nextPut: quote
]

{ #category : 'private' }
SimdCSVWriter >> needsQuotes: aString [
	^ aString isEmpty or: [
		  (aString includes: dialect separator) or: [
			  (aString includes: dialect quote) or: [
				  (aString includes: Character lf) or: [ (aString includes: Character cr) or: [ self isByteOrderMark: aString ] ] ] ] ]
]

{ #category : 'private' }
SimdCSVWriter >> isReadBack: aString [
	"Is aString a field as it is?"

	aString ifEmpty: [ ^ false ].
	(aString includes: dialect separator) ifTrue: [ ^ false ].
	(aString includes: Character lf) ifTrue: [ ^ false ].
	(dialect lineEnd ~~ #lf and: [ aString includes: Character cr ]) ifTrue: [ ^ false ].
	(self isByteOrderMark: aString) ifTrue: [ ^ false ].
	dialect quote ifNil: [ ^ true ].
	^ aString first ~= dialect quote and: [ dialect strictQuoting not or: [ (aString includes: dialect quote) not ] ]
]

{ #category : 'private' }
SimdCSVWriter >> isByteOrderMark: aString [
	"Would the reader skip the first character of aString, at the start of the output?"

	^ atStart and: [ fieldsDone = 1 and: [ aString first asInteger = 16rFEFF ] ]
]

{ #category : 'private' }
SimdCSVWriter >> textOf: anObject [
	anObject isString ifTrue: [ ^ anObject ].
	anObject isFloat ifTrue: [ ^ self textOfFloat: anObject ].
	anObject isInteger ifTrue: [ ^ anObject printString ].
	(anObject isKindOf: ScaledDecimal) ifTrue: [ ^ anObject printString copyUpTo: $s ].
	anObject isFraction ifTrue: [ ^ self textOfFloat: anObject asFloat ].
	^ anObject asString
]

{ #category : 'private' }
SimdCSVWriter >> textOfFloat: aFloat [
	aFloat isFinite ifTrue: [ ^ aFloat printString ].
	aFloat isNaN ifTrue: [ ^ 'nan' ].
	^ aFloat > 0.0
		  ifTrue: [ 'inf' ]
		  ifFalse: [ '-inf' ]
]
