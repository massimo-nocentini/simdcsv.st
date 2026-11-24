"
I convert the text of a field to a number, exactly, on my class side: the Integer, or the Float that is nearest to the decimal number (ties to even). I answer nil for a text that is no number.

- `integerFrom:`: a sign and decimal digits, at most 4,300 of them after the leading zeros;
- `floatFrom:comma:`: a sign, decimal digits with at most one point (or comma), and an exponent.

Spaces and tabs around the number are skipped. Nothing else is accepted: no radix, no digit groups, no nan, no inf.

```smalltalk
SimdCSVNumbers integerFrom: ' -12 '.
SimdCSVNumbers floatFrom: '1,5e3' comma: true.
```

The plugin converts the short numbers itself; what it leaves as text, I convert. The result of `Float class>>readFrom:` is not always the nearest Float, so I do not use it: I make the quotient or the product of two Integers and round it once.
"
Class {
	#name : 'SimdCSVNumbers',
	#superclass : 'Object',
	#category : 'SimdCSV-Core',
	#package : 'SimdCSV',
	#tag : 'Core'
}

{ #category : 'converting' }
SimdCSVNumbers class >> integerFrom: aString [
	"The Integer of aString, or nil"

	| start stop digits isNegative value chunk scale |
	start := self skipBlanksOf: aString.
	stop := self lastNonBlankOf: aString.
	start > stop ifTrue: [ ^ nil ].
	isNegative := (aString basicAt: start) = 45.
	(isNegative or: [ (aString basicAt: start) = 43 ]) ifTrue: [ start := start + 1 ].
	start > stop ifTrue: [ ^ nil ].
	value := chunk := digits := 0.
	scale := 1.
	start to: stop do: [ :i |
		| digit |
		digit := (aString basicAt: i) - 48.
		(digit between: 0 and: 9) ifFalse: [ ^ nil ].
		(digits > 0 or: [ digit > 0 ]) ifTrue: [ digits := digits + 1 ].
		digits > self maxIntegerDigits ifTrue: [ ^ nil ].
		chunk := chunk * 10 + digit.
		scale := scale * 10.
		scale = 100000000000000000 ifTrue: [
			value := value * scale + chunk.
			chunk := 0.
			scale := 1 ] ].
	value := value * scale + chunk.
	^ isNegative
		  ifTrue: [ value negated ]
		  ifFalse: [ value ]
]

{ #category : 'private' }
SimdCSVNumbers class >> maxIntegerDigits [
	"The largest count of digits of an Integer, leading zeros not counted: the conversion takes time with the square of it"

	^ 4300
]

{ #category : 'private' }
SimdCSVNumbers class >> maxSignificantDigits [
	"The digits of a mantissa that are kept: no number half-way between two Floats has more than 767"

	^ 800
]

{ #category : 'private' }
SimdCSVNumbers class >> skipBlanksOf: aString [
	"The index of the first character that is no space and no tab"

	1 to: aString size do: [ :i |
		| c |
		c := aString basicAt: i.
		(c = 32 or: [ c = 9 ]) ifFalse: [ ^ i ] ].
	^ aString size + 1
]

{ #category : 'private' }
SimdCSVNumbers class >> lastNonBlankOf: aString [
	"The index of the last character that is no space and no tab, or 0"

	aString size to: 1 by: -1 do: [ :i |
		| c |
		c := aString basicAt: i.
		(c = 32 or: [ c = 9 ]) ifFalse: [ ^ i ] ].
	^ 0
]

{ #category : 'converting' }
SimdCSVNumbers class >> floatFrom: aString comma: isComma [
	"The Float nearest to the number of aString, whose decimal point is a comma when isComma, or nil"

	| i stop point isNegative c mantissa kept digits exponent dropped seen inFraction value |
	i := self skipBlanksOf: aString.
	stop := self lastNonBlankOf: aString.
	i > stop ifTrue: [ ^ nil ].
	point := isComma
		         ifTrue: [ 44 ]
		         ifFalse: [ 46 ].
	isNegative := (aString basicAt: i) = 45.
	(isNegative or: [ (aString basicAt: i) = 43 ]) ifTrue: [ i := i + 1 ].
	mantissa := kept := exponent := 0.
	dropped := seen := inFraction := false.
	[ i <= stop and: [
		  c := aString basicAt: i.
		  (c between: 48 and: 57) or: [ c = point and: [ inFraction not ] ] ] ] whileTrue: [
		c = point
			ifTrue: [ inFraction := true ]
			ifFalse: [
				seen := true.
				(kept > 0 or: [ c > 48 ])
					ifTrue: [
						kept < self maxSignificantDigits
							ifTrue: [
								mantissa := mantissa * 10 + (c - 48).
								kept := kept + 1.
								inFraction ifTrue: [ exponent := exponent - 1 ] ]
							ifFalse: [
								c > 48 ifTrue: [ dropped := true ].
								inFraction ifFalse: [ exponent := exponent + 1 ] ] ]
					ifFalse: [ inFraction ifTrue: [ exponent := exponent - 1 ] ] ].
		i := i + 1 ].
	seen ifFalse: [ ^ nil ].
	i <= stop ifTrue: [
		digits := self exponentIn: aString from: i to: stop.
		digits ifNil: [ ^ nil ].
		exponent := exponent + digits ].
	value := self floatOf: mantissa digits: kept exponent: exponent sticky: dropped.
	^ isNegative
		  ifTrue: [ value * -1.0 ]
		  ifFalse: [ value ]
]

{ #category : 'private' }
SimdCSVNumbers class >> exponentIn: aString from: start to: stop [
	"The Integer of an exponent, e or E, a sign and digits, or nil.  It saturates far beyond the size of any String, so that it can be added to a count of digits"

	| i c isNegative value |
	c := aString basicAt: start.
	(c = 101 or: [ c = 69 ]) ifFalse: [ ^ nil ].
	i := start + 1.
	i > stop ifTrue: [ ^ nil ].
	isNegative := (aString basicAt: i) = 45.
	(isNegative or: [ (aString basicAt: i) = 43 ]) ifTrue: [ i := i + 1 ].
	i > stop ifTrue: [ ^ nil ].
	value := 0.
	i to: stop do: [ :k |
		c := (aString basicAt: k) - 48.
		(c between: 0 and: 9) ifFalse: [ ^ nil ].
		value := value * 10 + c min: 1000000000000000 ].
	^ isNegative
		  ifTrue: [ value negated ]
		  ifFalse: [ value ]
]

{ #category : 'private' }
SimdCSVNumbers class >> floatOf: mantissa digits: digits exponent: exponent sticky: isSticky [
	"The Float nearest to mantissa, an Integer of digits digits, times 10 to the power exponent; isSticky: non-zero digits of the number were dropped after mantissa.  The magnitude is tested first, so that no power of ten is made that the result does not need"

	| magnitude |
	mantissa = 0 ifTrue: [ ^ 0.0 ].
	magnitude := digits + exponent.
	magnitude > 310 ifTrue: [ ^ Float infinity ].
	magnitude < -330 ifTrue: [ ^ 0.0 ].
	^ isSticky
		  ifTrue: [ self floatOf: mantissa * 10 + 1 exponent: exponent - 1 ]
		  ifFalse: [ self floatOf: mantissa exponent: exponent ]
]

{ #category : 'converting' }
SimdCSVNumbers class >> floatOf: mantissa exponent: exponent [
	"The Float nearest to mantissa, an Integer, times 10 to the power exponent: one correctly rounded operation on exact Floats when both operands are, else one rounding of an Integer or of a Fraction"

	(mantissa <= 9007199254740992 and: [ exponent between: -22 and: 22 ]) ifTrue: [
		^ exponent < 0
			  ifTrue: [ mantissa asFloat / (10 raisedTo: exponent negated) asFloat ]
			  ifFalse: [ mantissa asFloat * (10 raisedTo: exponent) asFloat ] ].
	^ exponent < 0
		  ifTrue: [ (mantissa / (10 raisedTo: exponent negated)) asFloat ]
		  ifFalse: [ (mantissa * (10 raisedTo: exponent)) asFloat ]
]
