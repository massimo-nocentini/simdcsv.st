"
I hold the four primitives of the `SimdCSVPlugin`, on my class side only (`docs/SimdCSV.md` of `massimo-nocentini/pharo-vm`, section Primitive contract). `SimdCSVSmalltalk` answers the same selectors in pure Smalltalk; `SimdCSVBackend` chooses one of us.

Positions are 1-based and inclusive in the arguments and in the answers; the values inside an index are 0-based offsets from the base.

An answer is an Array whose first element is a status:

- 0, OK;
- 1, MORE: no slot of the destination left, the budget of objects used, or no memory after at least one row;
- 2, ERROR: a code and a position say which;
- 3, TOO_LARGE: more than 4,294,967,294 units from the base on;
- 4, NO_ROOM: the first record did not fit the object memory; `need` is its size in bytes.

The codes of an ERROR:

- 1, 2, 3: an unexpected quote, text after a closing quote, an unterminated quote (strict quoting);
- 4: invalid UTF-8;
- 5: another count of fields;
- 6: a bad index.

A failed primitive answers a `SimdCSVFailure` with its error code; `info` answers nil.
"
Class {
	#name : 'SimdCSVPrimitives',
	#superclass : 'Object',
	#category : 'SimdCSV-Backends',
	#package : 'SimdCSV',
	#tag : 'Backends'
}

{ #category : 'primitives' }
SimdCSVPrimitives class >> index: source base: base from: start to: stop dialect: word into: aWordArray from: destFrom [
	"{ status. stored. records. next. lines. minFields. maxFields. code. position }: the offsets from base of the ends of the fields of the complete records of source[start..stop], stored into aWordArray from destFrom on"

	<primitive: 'primitiveIndex' module: 'SimdCSVPlugin' error: ec>
	^ SimdCSVFailure on: ec
]

{ #category : 'primitives' }
SimdCSVPrimitives class >> info [
	"{ protocol. pluginVersion. simdcsvVersion. kernel. platform. kernels. forced note or nil. the largest span }, or nil without the plugin"

	<primitive: 'primitiveInfo' module: 'SimdCSVPlugin' error: ec>
	^ nil
]

{ #category : 'primitives' }
SimdCSVPrimitives class >> measure: source from: start to: stop dialect: word [
	"{ status. records. fields. next. lines. code. position } of the complete records of source[start..stop]"

	<primitive: 'primitiveMeasure' module: 'SimdCSVPlugin' error: ec>
	^ SimdCSVFailure on: ec
]

{ #category : 'primitives' }
SimdCSVPrimitives class >> rows: source base: base to: stop dialect: word index: anIndex from: indexFrom to: indexTo types: types fieldCount: fieldCount into: anArray from: destFrom wideStringClass: wideClass empty: emptyValue budget: budget [
	"{ status. rows. nextIndex. odd. code. position. row. field. need }: the records of the entries indexFrom to indexTo of anIndex, as Arrays stored into anArray from destFrom on"

	<primitive: 'primitiveRows' module: 'SimdCSVPlugin' error: ec>
	^ SimdCSVFailure on: ec
]
