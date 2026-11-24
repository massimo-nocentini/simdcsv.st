"
I am the backend without the plugin: my class side answers what the primitives of the `SimdCSVPlugin` answer, in pure Smalltalk, and I am the oracle of their tests (the comment of `SimdCSVPrimitives` has the statuses and the codes).

The answers are the same for every input, but for

- the slots of the destination beyond those stored,
- the budget of objects, which I do not count: a call for rows ends with MORE only when its destination is full.

The status NO_ROOM is never mine.

## The automaton

An `end` is the separator, LF or CR (not CR when only LF ends a line); the LF after a CR that ended a record belongs to that end.

- Start of a field: a quote opens a quoted field; an end ends an empty field; anything else begins an unquoted field.
- Unquoted: an end ends the field; a quote is irregular, and literal; anything else stays.
- Quoted: a quote may close the field; anything else stays.
- After that quote: another quote is an escaped quote, and the field goes on quoted; an end ends the field; anything else is irregular, literal, and the rest is unquoted.

With strict quoting the first irregular unit is an error. At the end of the data, a record that is not empty has an entry at its end; a field that is still quoted is irregular too.

## Instances

An instance works for one call: `scan` runs the automaton over the units `from` to `to`, `buildRows` walks an index and makes the rows, checking every entry, as the plugin does.
"
Class {
	#name : 'SimdCSVSmalltalk',
	#superclass : 'Object',
	#instVars : [
		'source',
		'units',
		'base',
		'from',
		'to',
		'separator',
		'quote',
		'cr',
		'isStrict',
		'skipsBlanks',
		'isLatin1',
		'isFinal',
		'countsLines',
		'isExact',
		'keepsQuotedEmpty',
		'dest',
		'destFrom',
		'capacity',
		'status',
		'code',
		'position',
		'stored',
		'records',
		'next',
		'minFields',
		'maxFields',
		'index',
		'slot',
		'slotEnd',
		'pos',
		'types',
		'fieldCount',
		'width',
		'wideClass',
		'emptyValue',
		'rows',
		'odd',
		'badRow',
		'badField',
		'textStart',
		'textEnd',
		'isPlain'
	],
	#category : 'SimdCSV-Backends',
	#package : 'SimdCSV',
	#tag : 'Backends'
}

{ #category : 'checking' }
SimdCSVSmalltalk class >> areSmallIntegers: anArray [
	"Whether the numbers of a call are SmallIntegers"

	^ anArray allSatisfy: [ :each | each class == SmallInteger ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> areTypes: types for: fieldCount [
	"Whether types is nil or a ByteArray of codes 0 to 4, as many as the fields of a row"

	types ifNil: [ ^ true ].
	types class == ByteArray ifFalse: [ ^ false ].
	(fieldCount > 0 and: [ types size ~= fieldCount ]) ifTrue: [ ^ false ].
	^ types allSatisfy: [ :each | each <= 4 ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> check: source dialect: word numbers: anArray ranges: aBlock [
	"The error code of a call that fails on its source, its numbers, its dialect or the ranges that aBlock tests, else nil"

	| kind |
	kind := self unitsOf: source.
	kind ifNil: [ ^ #'bad argument' ].
	(self areSmallIntegers: anArray) ifFalse: [ ^ #'bad argument' ].
	(self isDialect: word for: kind) ifFalse: [ ^ #'bad argument' ].
	^ aBlock value ifFalse: [ #'bad index' ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> check: source isNot: anObject [
	"The error code for the destination anObject of a call on source, else nil"

	source == anObject ifTrue: [ ^ #'bad argument' ].
	^ anObject isReadOnlyObject ifTrue: [ #'no modification' ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> isArray: anObject [
	"Whether anObject has the format of an Array, with no named slots"

	| class |
	class := anObject class.
	^ class instSpec = 2 and: [ class instSize = 0 ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> isDialect: word for: kind [
	"Whether the primitives take the dialect word for a source of kind #bytes or #words"

	| separator quote flags |
	(word < 0 or: [ (word bitShift: -29) > 511 ]) ifTrue: [ ^ false ].
	separator := word bitAnd: 16r1FFFFF.
	quote := (word bitShift: -21) bitAnd: 255.
	flags := word bitShift: -29.
	(separator = 10 or: [ separator = 13 ]) ifTrue: [ ^ false ].
	(separator = quote and: [ (flags bitAnd: SimdCSVDialect flagNoQuote) = 0 ]) ifTrue: [ ^ false ].
	(quote = 10 or: [ quote = 13 ]) ifTrue: [ ^ false ].
	kind == #words ifTrue: [ ^ (flags bitAnd: SimdCSVDialect flagLatin1) = 0 ].
	separator > 255 ifTrue: [ ^ false ].
	^ (flags bitAnd: SimdCSVDialect flagLatin1) ~= 0 or: [ separator <= 127 and: [ quote <= 127 ] ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> isWideStringClass: anObject [
	"Whether anObject is a class of objects of 32-bit words without named slots, but not the class of the boxed Floats"

	^ anObject class class == Metaclass and: [
		  anObject instSpec = 10 and: [ anObject instSize = 0 and: [ anObject ~~ BoxedFloat64 ] ] ]
]

{ #category : 'checking' }
SimdCSVSmalltalk class >> unitsOf: anObject [
	"#bytes or #words: what the primitives read anObject as, or nil"

	| spec |
	spec := anObject class instSpec.
	spec = 16 ifTrue: [ ^ #bytes ].
	^ spec = 10 ifTrue: [ #words ]
]

{ #category : 'backend' }
SimdCSVSmalltalk class >> index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom [
	"{ status. stored. records. next. lines. minFields. maxFields. code. position }: the offsets from base of the ends of the fields of the complete records of source[start..stop], stored into aWordArray from destFrom on"

	| ec |
	ec := self
		      check: source
		      dialect: word
		      numbers: { base. start. stop. word. destFrom }
		      ranges: [ base >= 1 and: [ base <= start and: [ start <= (stop + 1) and: [ stop <= source basicSize ] ] ] ].
	ec ifNotNil: [ ^ SimdCSVFailure on: ec ].
	(self unitsOf: aWordArray) == #words ifFalse: [ ^ SimdCSVFailure on: #'bad argument' ].
	(destFrom between: 1 and: aWordArray basicSize + 1) ifFalse: [ ^ SimdCSVFailure on: #'bad index' ].
	ec := self check: source isNot: aWordArray.
	ec ifNotNil: [ ^ SimdCSVFailure on: ec ].
	^ (self new source: source base: base from: start to: stop dialect: word) indexInto: aWordArray from: destFrom
]

{ #category : 'backend' }
SimdCSVSmalltalk class >> info [
	"What primitiveInfo answers, for me"

	^ {
		  1.
		  'SimdCSVSmalltalk 1.0'.
		  nil.
		  'smalltalk'.
		  'smalltalk'.
		  #( 'smalltalk' ).
		  nil.
		  self maxSpan }
]

{ #category : 'accessing' }
SimdCSVSmalltalk class >> maxFieldCount [
	"SC_MAX_FIELD_COUNT: the largest count of fields of a row"

	^ 16777216
]

{ #category : 'accessing' }
SimdCSVSmalltalk class >> maxSpan [
	"SC_MAX_SPAN: the largest count of units that one index spans"

	^ 4294967294
]

{ #category : 'backend' }
SimdCSVSmalltalk class >> measure: source from: start to: stop dialect: word [
	"{ status. records. fields. next. lines. code. position } of the complete records of source[start..stop]"

	| ec |
	ec := self
		      check: source
		      dialect: word
		      numbers: { start. stop. word }
		      ranges: [ start >= 1 and: [ start <= (stop + 1) and: [ stop <= source basicSize ] ] ].
	ec ifNotNil: [ ^ SimdCSVFailure on: ec ].
	^ (self new source: source base: start from: start to: stop dialect: word) measure
]

{ #category : 'backend' }
SimdCSVSmalltalk class >> rows: source base: base to: stop dialect: word index: anIndex from: indexFrom to: indexTo types: types fieldCount: fieldCount into: anArray from: destFrom wideStringClass: wideClass empty: emptyValue budget: budget [
	"{ status. rows. nextIndex. odd. code. position. row. field. need }: the records of the entries indexFrom to indexTo of anIndex, as Arrays stored into anArray from destFrom on.  The budget is not counted"

	| ec |
	ec := self
		      check: source
		      dialect: word
		      numbers: { base. stop. word. indexFrom. indexTo. fieldCount. destFrom. budget }
		      ranges: [
			      base >= 1 and: [
				      base <= (stop + 1) and: [
					      stop <= source basicSize and: [ fieldCount between: 0 and: self maxFieldCount ] ] ] ].
	ec ifNotNil: [ ^ SimdCSVFailure on: ec ].
	(self unitsOf: anIndex) == #words ifFalse: [ ^ SimdCSVFailure on: #'bad argument' ].
	(indexFrom >= 1 and: [ indexTo >= (indexFrom - 1) and: [ indexTo <= anIndex basicSize ] ]) ifFalse: [
		^ SimdCSVFailure on: #'bad index' ].
	(self isArray: anArray) ifFalse: [ ^ SimdCSVFailure on: #'bad argument' ].
	(destFrom between: 1 and: anArray size + 1) ifFalse: [ ^ SimdCSVFailure on: #'bad index' ].
	(self isWideStringClass: wideClass) ifFalse: [ ^ SimdCSVFailure on: #'bad argument' ].
	(self areTypes: types for: fieldCount) ifFalse: [ ^ SimdCSVFailure on: #'bad argument' ].
	ec := self check: source isNot: anArray.
	ec ifNotNil: [ ^ SimdCSVFailure on: ec ].
	^ (self new source: source base: base from: base to: stop dialect: word)
		  index: anIndex from: indexFrom to: indexTo;
		  types: types fieldCount: fieldCount wideStringClass: wideClass empty: emptyValue;
		  rowsInto: anArray from: destFrom
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> addEndAt: p fields: count [
	"The end of the field number count of the open record is at p: store it, and answer whether there was a slot"

	| k |
	k := stored + count.
	k > capacity ifTrue: [
		status := SimdCSVBackend statusMore.
		^ false ].
	dest ifNotNil: [ dest basicAt: destFrom + k - 1 put: p - base ].
	^ true
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> after: p [
	"The position after the line end at p: an LF after a CR belongs to it"

	^ ((source basicAt: p) = cr and: [ p < to and: [ (source basicAt: p + 1) = 10 ] ])
		  ifTrue: [ p + 2 ]
		  ifFalse: [ p + 1 ]
]

{ #category : 'rows' }
SimdCSVSmalltalk >> buildRows [
	"Make the rows of the entries slot to slotEnd, one record after the other"

	slot > slotEnd ifTrue: [ ^ self ].
	self openCursor ifFalse: [ ^ self failRecord: SimdCSVBackend codeBadIndex at: 0 field: 0 ].
	[ slot <= slotEnd ] whileTrue: [
		| count row |
		rows = capacity ifTrue: [ ^ status := SimdCSVBackend statusMore ].
		self skipBlankLines.
		count := self countFields.
		count ifNil: [ ^ self failRecord: SimdCSVBackend codeBadIndex at: pos field: 0 ].
		(isExact and: [ fieldCount > 0 and: [ count ~= fieldCount ] ]) ifTrue: [
			^ self failRecord: SimdCSVBackend codeFieldCount at: pos field: count ].
		row := self rowOf: count.
		row ifNil: [ ^ self failRecord: SimdCSVBackend codeInvalidUTF8 at: position field: badField ].
		dest at: destFrom + rows put: row.
		rows := rows + 1.
		slot := slot + count ]
]

{ #category : 'rows' }
SimdCSVSmalltalk >> cellFrom: start to: stop type: type [
	"The cell of the field of the units start to stop, whose type is 1 to 4; position is not 0 when its text is not UTF-8"

	| quoted value |
	quoted := self findTextFrom: start to: stop.
	textStart > textEnd ifTrue: [
		^ (quoted and: [ keepsQuotedEmpty and: [ type = 1 ] ])
			  ifTrue: [ ByteString new: 0 ]
			  ifFalse: [ emptyValue ] ].
	type = 1 ifTrue: [ ^ self stringFrom: start to: stop ].
	isPlain ifTrue: [
		value := type = 2
			         ifTrue: [ self integer ]
			         ifFalse: [
				         self floatWithPoint: (type = 3
						          ifTrue: [ 46 ]
						          ifFalse: [ 44 ]) ].
		value ifNotNil: [ ^ value ] ].
	odd := odd + 1.
	^ self stringFrom: start to: stop
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> commitRecordOf: count [
	"The open record, of count fields, is complete"

	stored := stored + count.
	records := records + 1.
	minFields := records = 1
		             ifTrue: [ count ]
		             ifFalse: [ minFields min: count ].
	maxFields := maxFields max: count
]

{ #category : 'rows' }
SimdCSVSmalltalk >> countFields [
	"The count of fields of the record that begins at pos with the entry slot, or nil when an entry is not the end of a field there"

	| start k count end unit |
	pos > to ifTrue: [ ^ nil ].
	start := pos.
	k := slot.
	count := 0.
	[ k <= slotEnd ] whileTrue: [
		end := base + (index basicAt: k).
		(end < start or: [ end > (to + 1) ]) ifTrue: [ ^ nil ].
		count := count + 1.
		end > to ifTrue: [ ^ count ].
		unit := source basicAt: end.
		unit = separator
			ifTrue: [ start := end + 1 ]
			ifFalse: [
				^ (unit = 10 or: [ unit = cr ]) ifTrue: [ count ] ].
		k := k + 1 ].
	^ nil
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> countLines [
	"The physical line ends of the units from to next - 1, quoted ones too, CRLF once"

	| lines unit previous |
	countsLines ifFalse: [ ^ 0 ].
	lines := 0.
	previous := 0.
	from to: next - 1 do: [ :p |
		unit := source basicAt: p.
		unit = 10
			ifTrue: [ previous = cr ifFalse: [ lines := lines + 1 ] ]
			ifFalse: [ unit = cr ifTrue: [ lines := lines + 1 ] ].
		previous := unit ].
	^ lines
]

{ #category : 'text' }
SimdCSVSmalltalk >> decodeUTF8: bytes from: start to: stop [
	"The narrowest String of the UTF-8 of the bytes start to stop, or nil with position, the index in bytes of the first byte of the first bad sequence"

	| codePoints count largest i lead need low high point |
	codePoints := WordArray new: stop - start + 1.
	count := largest := 0.
	i := start.
	[ i <= stop ] whileTrue: [
		lead := bytes basicAt: i.
		low := 16r80.
		high := 16rBF.
		lead < 16r80
			ifTrue: [
				need := 0.
				point := lead ]
			ifFalse: [
				lead < 16rE0
					ifTrue: [
						need := lead < 16rC2
							        ifTrue: [ stop ]
							        ifFalse: [ 1 ].
						point := lead bitAnd: 16r1F ]
					ifFalse: [
						lead < 16rF0
							ifTrue: [
								need := 2.
								point := lead bitAnd: 16rF.
								lead = 16rE0 ifTrue: [ low := 16rA0 ].
								lead = 16rED ifTrue: [ high := 16r9F ] ]
							ifFalse: [
								need := lead > 16rF4
									        ifTrue: [ stop ]
									        ifFalse: [ 3 ].
								point := lead bitAnd: 7.
								lead = 16rF0 ifTrue: [ low := 16r90 ].
								lead = 16rF4 ifTrue: [ high := 16r8F ] ] ] ].
		i + need > stop ifTrue: [
			position := i.
			^ nil ].
		1 to: need do: [ :k |
			| byte |
			byte := bytes basicAt: i + k.
			(byte between: low and: high) ifFalse: [
				position := i.
				^ nil ].
			low := 16r80.
			high := 16rBF.
			point := (point bitShift: 6) + (byte bitAnd: 16r3F) ].
		count := count + 1.
		codePoints at: count put: point.
		point > largest ifTrue: [ largest := point ].
		i := i + need + 1 ].
	^ self stringOf: codePoints from: 1 to: count largest: largest
]

{ #category : 'rows' }
SimdCSVSmalltalk >> failRecord: anInteger at: aPosition field: aField [
	"The record after the rows made is in error"

	status := SimdCSVBackend statusError.
	code := anInteger.
	position := aPosition.
	badRow := rows + 1.
	badField := aField
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> failScan: anInteger at: aPosition [
	status := SimdCSVBackend statusError.
	code := anInteger.
	position := aPosition
]

{ #category : 'text' }
SimdCSVSmalltalk >> findTextFrom: start to: stop [
	"Set textStart, textEnd and isPlain to the text of the field of the units start to stop, and answer whether the field is quoted: a quoted field's text is after the first quote, two quotes there are one, the next lone quote closes, and the rest is literal; isPlain: the text is the units textStart to textEnd as they are"

	| p |
	textStart := start.
	textEnd := stop.
	isPlain := true.
	(start <= stop and: [ (source basicAt: start) = quote ]) ifFalse: [ ^ false ].
	textStart := start + 1.
	p := textStart.
	[ p <= stop and: [ (source basicAt: p) ~= quote ] ] whileTrue: [ p := p + 1 ].
	p > stop ifTrue: [ ^ true ].
	isPlain := p = stop.
	textEnd := isPlain
		           ifTrue: [ stop - 1 ]
		           ifFalse: [ stop ].
	^ true
]

{ #category : 'numbers' }
SimdCSVSmalltalk >> floatWithPoint: point [
	"The Float of the text, whose decimal point is the unit point, when its mantissa and its power of ten are exact Floats (at most 19 digits, as the plugin), else nil"

	| p last unit isNegative mantissa digits fraction inFraction seen exponent value |
	p := textStart.
	last := textEnd.
	[ p <= last and: [ self isBlank: (source basicAt: p) ] ] whileTrue: [ p := p + 1 ].
	[ p <= last and: [ self isBlank: (source basicAt: last) ] ] whileTrue: [ last := last - 1 ].
	p > last ifTrue: [ ^ nil ].
	isNegative := (source basicAt: p) = 45.
	(isNegative or: [ (source basicAt: p) = 43 ]) ifTrue: [ p := p + 1 ].
	mantissa := digits := fraction := 0.
	inFraction := seen := false.
	[ p <= last and: [
		  unit := source basicAt: p.
		  (unit between: 48 and: 57) or: [ unit = point and: [ inFraction not ] ] ] ] whileTrue: [
		unit = point
			ifTrue: [ inFraction := true ]
			ifFalse: [
				seen := true.
				inFraction ifTrue: [ fraction := fraction + 1 ].
				(digits > 0 or: [ unit > 48 ]) ifTrue: [
					digits := digits + 1.
					digits > 19 ifFalse: [ mantissa := mantissa * 10 + unit - 48 ] ] ].
		p := p + 1 ].
	seen ifFalse: [ ^ nil ].
	exponent := self exponentFrom: p to: last.
	exponent ifNil: [ ^ nil ].
	(digits > 19 or: [ mantissa > 9007199254740992 ]) ifTrue: [ ^ nil ].
	exponent := exponent - fraction.
	exponent < -22 ifTrue: [ ^ nil ].
	exponent > 22 ifTrue: [
		exponent > 37 ifTrue: [ ^ nil ].
		mantissa := mantissa * (10 raisedTo: exponent - 22).
		mantissa > 9007199254740992 ifTrue: [ ^ nil ].
		exponent := 22 ].
	value := SimdCSVNumbers floatOf: mantissa exponent: exponent.
	^ isNegative
		  ifTrue: [ value * -1.0 ]
		  ifFalse: [ value ]
]

{ #category : 'numbers' }
SimdCSVSmalltalk >> exponentFrom: start to: stop [
	"The exponent of the units start to stop, 0 when there are none, or nil when they are no exponent; it saturates at 99999"

	| p unit isNegative value |
	start > stop ifTrue: [ ^ 0 ].
	unit := source basicAt: start.
	(unit = 101 or: [ unit = 69 ]) ifFalse: [ ^ nil ].
	p := start + 1.
	p > stop ifTrue: [ ^ nil ].
	isNegative := (source basicAt: p) = 45.
	(isNegative or: [ (source basicAt: p) = 43 ]) ifTrue: [ p := p + 1 ].
	p > stop ifTrue: [ ^ nil ].
	value := 0.
	p to: stop do: [ :k |
		unit := (source basicAt: k) - 48.
		(unit between: 0 and: 9) ifFalse: [ ^ nil ].
		value := value * 10 + unit min: 99999 ].
	^ isNegative
		  ifTrue: [ value negated ]
		  ifFalse: [ value ]
]

{ #category : 'initialization' }
SimdCSVSmalltalk >> index: anIndex from: indexFrom to: indexTo [
	index := anIndex.
	slot := indexFrom.
	slotEnd := indexTo
]

{ #category : 'backend' }
SimdCSVSmalltalk >> indexInto: aWordArray from: anInteger [
	to - base + 1 > self class maxSpan ifTrue: [
		^ {
			  SimdCSVBackend statusTooLarge.
			  0.
			  0.
			  from.
			  0.
			  0.
			  0.
			  0.
			  0 } ].
	dest := aWordArray.
	destFrom := anInteger.
	capacity := aWordArray basicSize - anInteger + 1.
	self scan.
	^ {
		  status.
		  stored.
		  records.
		  next.
		  self countLines.
		  minFields.
		  maxFields.
		  code.
		  position }
]

{ #category : 'numbers' }
SimdCSVSmalltalk >> integer [
	"The Integer of the text when it has at most 18 digits after the leading zeros, else nil"

	| p last unit isNegative value digits |
	p := textStart.
	last := textEnd.
	[ p <= last and: [ self isBlank: (source basicAt: p) ] ] whileTrue: [ p := p + 1 ].
	[ p <= last and: [ self isBlank: (source basicAt: last) ] ] whileTrue: [ last := last - 1 ].
	p > last ifTrue: [ ^ nil ].
	isNegative := (source basicAt: p) = 45.
	(isNegative or: [ (source basicAt: p) = 43 ]) ifTrue: [ p := p + 1 ].
	p > last ifTrue: [ ^ nil ].
	value := digits := 0.
	p to: last do: [ :k |
		unit := (source basicAt: k) - 48.
		(unit between: 0 and: 9) ifFalse: [ ^ nil ].
		(digits > 0 or: [ unit > 0 ]) ifTrue: [ digits := digits + 1 ].
		digits > 18 ifTrue: [ ^ nil ].
		value := value * 10 + unit ].
	^ isNegative
		  ifTrue: [ 0 - value ]
		  ifFalse: [ value ]
]

{ #category : 'numbers' }
SimdCSVSmalltalk >> isBlank: unit [
	"Whether unit is a space or a tab"

	^ unit = 32 or: [ unit = 9 ]
]

{ #category : 'backend' }
SimdCSVSmalltalk >> measure [
	"{ status. records. fields. next. lines. code. position }"

	capacity := SmallInteger maxVal.
	self scan.
	^ {
		  status.
		  records.
		  stored.
		  next.
		  self countLines.
		  code.
		  position }
]

{ #category : 'rows' }
SimdCSVSmalltalk >> openCursor [
	"Set pos to the start of the record whose first entry is slot: the base, or the unit after the line end at the entry before; answer whether there is one"

	| end unit |
	pos := base.
	slot = 1 ifTrue: [ ^ true ].
	end := base + (index basicAt: slot - 1).
	end > to ifTrue: [ ^ false ].
	unit := source basicAt: end.
	(unit = 10 or: [ unit = cr ]) ifFalse: [ ^ false ].
	pos := self after: end.
	^ true
]

{ #category : 'rows' }
SimdCSVSmalltalk >> rowOf: count [
	"The Array of the record of count fields at pos, with pos moved to the next record, or nil with position and badField when a text is not UTF-8"

	| row k start end type oddBefore |
	row := Array
		       new: (fieldCount = 0
				        ifTrue: [ self widthOf: count ]
				        ifFalse: [ width ])
		       withAll: emptyValue.
	oddBefore := odd.
	k := 0.
	start := pos.
	1 to: count do: [ :i |
		end := base + (index basicAt: slot + i - 1).
		type := (fieldCount > 0 and: [ i > fieldCount ])
			        ifTrue: [ 0 ]
			        ifFalse: [ self typeOf: i ].
		type = 0 ifFalse: [
			k := k + 1.
			row at: k put: (self cellFrom: start to: end - 1 type: type).
			position = 0 ifFalse: [
				odd := oddBefore.
				badField := i.
				^ nil ] ].
		i < count ifTrue: [ start := end + 1 ] ].
	pos := end > to
		       ifTrue: [ end ]
		       ifFalse: [ self after: end ].
	^ row
]

{ #category : 'backend' }
SimdCSVSmalltalk >> rowsInto: anArray from: anInteger [
	dest := anArray.
	destFrom := anInteger.
	capacity := anArray size - anInteger + 1.
	width := self widthOf: fieldCount.
	self buildRows.
	^ {
		  status.
		  rows.
		  slot.
		  odd.
		  code.
		  position.
		  badRow.
		  badField.
		  0 }
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> scan [
	"Run the automaton over the units from to to, storing the ends of the fields.  state: 0 the start of a field, 1 unquoted, 2 quoted, 3 after a quote in a quoted field"

	| p state unit fields opening |
	p := from.
	state := fields := opening := 0.
	[ p <= to ] whileTrue: [
		unit := source basicAt: p.
		state = 2
			ifTrue: [
				unit = quote ifTrue: [ state := 3 ].
				p := p + 1 ]
			ifFalse: [
				(unit = separator or: [ unit = 10 or: [ unit = cr ] ])
					ifTrue: [
						(skipsBlanks and: [ p = next and: [ unit ~= separator ] ])
							ifTrue: [
								(self waitsForMoreAt: p unit: unit) ifTrue: [ ^ self ].
								p := next := self after: p ]
							ifFalse: [
								fields := fields + 1.
								(self addEndAt: p fields: fields) ifFalse: [ ^ self ].
								unit = separator
									ifTrue: [ p := p + 1 ]
									ifFalse: [
										(self waitsForMoreAt: p unit: unit) ifTrue: [ ^ self ].
										self commitRecordOf: fields.
										fields := 0.
										p := next := self after: p ] ].
						state := 0 ]
					ifFalse: [
						unit = quote
							ifTrue: [
								state = 0
									ifTrue: [
										state := 2.
										opening := p ]
									ifFalse: [
										state = 3
											ifTrue: [ state := 2 ]
											ifFalse: [
												isStrict ifTrue: [ ^ self failScan: SimdCSVBackend codeUnexpectedQuote at: p ] ] ] ]
							ifFalse: [
								(state = 3 and: [ isStrict ]) ifTrue: [ ^ self failScan: SimdCSVBackend codeTextAfterQuote at: p ].
								state := 1 ].
						p := p + 1 ] ] ].
	isFinal ifFalse: [ ^ self ].
	(state = 2 and: [ isStrict ]) ifTrue: [ ^ self failScan: SimdCSVBackend codeUnterminatedQuote at: opening ].
	next > to ifTrue: [ ^ self ].
	(self addEndAt: to + 1 fields: fields + 1) ifFalse: [ ^ self ].
	self commitRecordOf: fields + 1.
	next := to + 1
]

{ #category : 'rows' }
SimdCSVSmalltalk >> skipBlankLines [
	"Move pos over the blank lines at the start of a record"

	| unit |
	skipsBlanks ifFalse: [ ^ self ].
	[ pos <= to and: [
		  unit := source basicAt: pos.
		  unit = 10 or: [ unit = cr ] ] ] whileTrue: [ pos := pos + 1 ]
]

{ #category : 'initialization' }
SimdCSVSmalltalk >> source: anObject base: baseInteger from: start to: stop dialect: word [
	| flags |
	source := anObject.
	units := self class unitsOf: anObject.
	base := baseInteger.
	from := next := start.
	to := stop.
	separator := word bitAnd: 16r1FFFFF.
	flags := word bitShift: -29.
	"a unit that no quote and no CR can be"
	quote := (flags bitAnd: SimdCSVDialect flagNoQuote) = 0
		         ifTrue: [ (word bitShift: -21) bitAnd: 255 ]
		         ifFalse: [ -1 ].
	cr := (flags bitAnd: SimdCSVDialect flagLfOnly) = 0
		      ifTrue: [ 13 ]
		      ifFalse: [ -1 ].
	isStrict := (flags bitAnd: SimdCSVDialect flagStrict) ~= 0.
	skipsBlanks := (flags bitAnd: SimdCSVDialect flagSkipBlank) ~= 0.
	isLatin1 := (flags bitAnd: SimdCSVDialect flagLatin1) ~= 0.
	isFinal := (flags bitAnd: SimdCSVDialect flagFinal) ~= 0.
	countsLines := (flags bitAnd: SimdCSVDialect flagLines) ~= 0.
	isExact := (flags bitAnd: SimdCSVDialect flagExactCount) ~= 0.
	keepsQuotedEmpty := (flags bitAnd: SimdCSVDialect flagKeepQuotedEmpty) ~= 0.
	status := code := position := stored := records := minFields := maxFields := rows := odd := badRow := badField := 0
]

{ #category : 'text' }
SimdCSVSmalltalk >> stringFrom: start to: stop [
	"The narrowest String of the text of the field of the units start to stop, that findTextFrom:to: found, or nil with position when it is not UTF-8"

	| buffer count string |
	isPlain ifTrue: [ ^ self stringOf: source from: textStart to: textEnd ].
	buffer := WordArray new: stop - start.
	count := self unescapeInto: buffer.
	string := self stringOf: buffer from: 1 to: count.
	string ifNil: [ position := self unescapeInto: (WordArray new: position) ].
	^ string
]

{ #category : 'text' }
SimdCSVSmalltalk >> stringOf: anArray from: start to: stop [
	"The narrowest String of the units start to stop of anArray, or nil with position, an index of anArray, when they are not UTF-8"

	| all largest unit |
	all := largest := 0.
	start to: stop do: [ :i |
		unit := anArray basicAt: i.
		all := all bitOr: unit.
		unit > largest ifTrue: [ largest := unit ] ].
	(units == #bytes and: [ isLatin1 not and: [ all > 127 ] ]) ifTrue: [
		^ self decodeUTF8: anArray from: start to: stop ].
	^ self stringOf: anArray from: start to: stop largest: largest
]

{ #category : 'text' }
SimdCSVSmalltalk >> stringOf: anArray from: start to: stop largest: largest [
	"The String of the code points start to stop of anArray, a ByteString when the largest is below 256"

	| string |
	string := (largest < 256
		           ifTrue: [ ByteString ]
		           ifFalse: [ wideClass ]) basicNew: stop - start + 1.
	start to: stop do: [ :i | string basicAt: i - start + 1 put: (anArray basicAt: i) ].
	^ string
]

{ #category : 'rows' }
SimdCSVSmalltalk >> typeOf: field [
	"The code of the type of a field: 0 ignored, 1 a String, 2 an Integer, 3 a Float, 4 a Float with a decimal comma"

	types ifNil: [ ^ 1 ].
	^ field > types size
		  ifTrue: [ 1 ]
		  ifFalse: [ types at: field ]
]

{ #category : 'initialization' }
SimdCSVSmalltalk >> types: aByteArrayOrNil fieldCount: anInteger wideStringClass: aClass empty: anObject [
	types := aByteArrayOrNil.
	fieldCount := anInteger.
	wideClass := aClass.
	emptyValue := anObject
]

{ #category : 'text' }
SimdCSVSmalltalk >> unescapeInto: buffer [
	"Store the units of the text of a quoted field, textStart to textEnd, into buffer, two quotes as one and the lone closing quote left out; answer their count, or, once buffer is full, the position in the source of the last one"

	| p count unit isOpen |
	p := textStart.
	count := 0.
	isOpen := true.
	[ p <= textEnd ] whileTrue: [
		unit := source basicAt: p.
		(isOpen and: [ unit = quote and: [
			  (p < textEnd and: [ (source basicAt: p + 1) = quote ])
				  ifTrue: [
					  p := p + 1.
					  false ]
				  ifFalse: [ true ] ] ])
			ifTrue: [ isOpen := false ]
			ifFalse: [
				count := count + 1.
				buffer at: count put: unit.
				count = buffer size ifTrue: [ ^ p ] ].
		p := p + 1 ].
	^ count
]

{ #category : 'scanning' }
SimdCSVSmalltalk >> waitsForMoreAt: p unit: unit [
	"Whether the line end at p may go on with the next data: a CR in the last position, unless the data end there"

	^ unit = cr and: [ p = to and: [ isFinal not ] ]
]

{ #category : 'rows' }
SimdCSVSmalltalk >> widthOf: count [
	"The size of the row of count fields: those whose type is not 0"

	types ifNil: [ ^ count ].
	^ (1 to: count) count: [ :i | (self typeOf: i) ~= 0 ]
]
