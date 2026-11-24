# simdcsv.st

Reading and writing CSV for Pharo 12 to 15, with [simdcsv](https://github.com/geofflangdale/simdcsv).

The work is done by the SimdCSVPlugin of the VM of [massimo-nocentini/pharo-vm](https://github.com/massimo-nocentini/pharo-vm) (`plugins/SimdCSVPlugin`, whose `docs/SimdCSV.md` is the contract), which finds the ends of the fields 64 bytes at a time and builds the rows in C, or in pure Smalltalk without it: both answer the same rows, numbers, errors and positions.

- `SimdCSV` is the facade: rows, Dictionaries, tables, counts, and back.
- `SimdCSVReader` has the protocol of `NeoCSVReader`: typed fields, converters, record classes, headers; files and streams of any size in constant memory.
- `SimdCSVTable` is a text with its index: rows and columns are made when they are asked for.
- `SimdCSVWriter` has the protocol of `NeoCSVWriter`, but for its private messages.
- `SimdCSVDialect` says how the text is written.

Nothing of Pharo is replaced, nothing of NeoCSV is needed or shadowed, and the one extension method is `simdCSVFailed`.
This repository is the submodule `plugins/SimdCSVPlugin/simdcsv.st` of that VM, whose commit is the version of the Smalltalk code that goes with the plugin.

## Requirements

- Pharo 12, 13, 14 or 15.
- For speed, a 64-bit VM with the SimdCSVPlugin. Without it everything works in pure Smalltalk, at about the speed of NeoCSV.

## Loading

    Metacello new
    	baseline: 'SimdCSV';
    	repository: 'github://massimo-nocentini/simdcsv.st:master/src';
    	load: #( 'Core' )

Groups: `Core` (the package `SimdCSV`), `Tests` (`SimdCSV-Tests`), `default` (both), and, only when asked for, `NeoTests` (`SimdCSV-NeoTests`, the comparison with NeoCSV, which it downloads).
From a checkout of the VM, `plugins/SimdCSVPlugin/tests/load-simdcsv.st` loads the submodule, and `plugins/SimdCSVPlugin/tests/run-st-tests.sh` runs the tests.

In the examples below, the comment that begins with `=>` is what the statements before it, up to the blank line, answer.

## Rows

A source is a String, a Symbol, a ByteArray, a FileReference or a stream. Bytes are UTF-8 unless the dialect says `#latin1`; a file is read as bytes.

```smalltalk
SimdCSV rowsFrom: 'id,name' , String lf , '1,"Rossi, Mario"' , String lf , '2,' , String lf
"=> #(#('id' 'name') #('1' 'Rossi, Mario') #('2' nil))"

SimdCSV rowsFrom: 'a;b' separator: $;
"=> #(#('a' 'b'))"

SimdCSV rowsFrom: #[195 169 44 98]
"=> #(#('é' 'b'))"

| names |
names := OrderedCollection new.
SimdCSV rowsFrom: 'x,1' , String lf , 'y,2' do: [ :row | names add: row first ].
names asArray
"=> #('x' 'y')"

SimdCSV count: 'a,b' , String lf , '1,2' , String lf
"=> 2"

(SimdCSV dictionariesFrom: 'id,name' , String lf , '1,Anna') first at: #name
"=> 'Anna'"
```

A row has as many fields as its record; an empty field is nil, quoted or not (see the dialect). `rowsFrom:do:` takes memory that does not grow with the source; `count:` makes no row.

Bytes of another encoding than UTF-8: Latin-1 is read as it is, the others are decoded first.

```smalltalk
| latin1 |
latin1 := SimdCSVDialect new
	encoding: #latin1;
	yourself.
SimdCSV rowsFrom: #[233 44 98] dialect: latin1
"=> #(#('é' 'b'))"
```

## Dialects

```smalltalk
| dialect |
dialect := SimdCSVDialect semicolon.
dialect
	lineEnd: #lf;
	skipEmptyLines: true;
	keepQuotedEmpty: true.
SimdCSV rowsFrom: 'a;""' , String lf , String lf , 'b;' , String lf dialect: dialect
"=> #(#('a' '') #('b' nil))"
```

`SimdCSVDialect comma` (the default), `semicolon` and `tab` answer new ones; `separator:`, `quote:` (nil for none), `lineEnd:` (`#any`: LF, CR and CRLF, mixed; `#lf`), `strictQuoting:`, `strictFieldCount:`, `skipEmptyLines:`, `keepQuotedEmpty:`, `encoding:` (`#utf8` or `#latin1`), `emptyFieldValue:`, `hasHeader:` and `nullTexts:` change one. Every message of `SimdCSV` has a form with `dialect:`.

By default the quotes are read as leniently as Python's csv module reads them, and blank lines are records of one empty field.

```smalltalk
SimdCSV rowsFrom: '"a"b,c"d'
"=> #(#('ab' 'c""d'))"

[ SimdCSV rowsFrom: 'a' , String lf , 'b"c' dialect: (SimdCSVDialect new strictQuoting: true; yourself) ]
	on: SimdCSVQuoteError
	do: [ :error | error messageText ]
"=> 'Unexpected quote at character 4 (record 2, line 2)'"
```

## Typed fields and records

`SimdCSVReader` is configured as a `NeoCSVReader` is. Fields are declared in their order, with an accessor when the records are objects:

```smalltalk
(SimdCSVReader on: 'id,name,price' , String lf , '7,bolt,0.25' , String lf , '8,nut,')
	skipHeader;
	addIntegerField;
	addField;
	addFloatField;
	upToEnd
"=> #(#(7 'bolt' 0.25) #(8 'nut' nil))"

((SimdCSVReader on: 'x;10:30;' , String lf , 'y;11:15;3')
	separator: $;;
	recordClass: Dictionary;
	addFieldAt: #stop;
	addFieldAt: #time converter: [ :text | (text splitOn: $:) collect: #asInteger as: Array ];
	addIntegerFieldAt: #platform;
	next) at: #time
"=> #(10 30)"
```

A file is read in batches, whatever its size, and `on:do:` closes it:

```smalltalk
| file sum |
file := FileSystem memory / 'readings.csv'.
file writeStreamDo: [ :stream | stream nextPutAll: 'station,value' , String lf , 'a,1.5' , String lf , 'b,2' , String lf ].
sum := 0.
SimdCSVReader on: file do: [ :reader |
	reader
		skipHeader;
		addField;
		addFloatField;
		do: [ :row | sum := sum + row second ] ].
sum
"=> 3.5"
```

Or they are taken by the names of a header:

```smalltalk
| reader |
reader := SimdCSVReader on: 'id,city,lat,lon' , String lf , '1,Firenze,43.77,11.25' , String lf.
reader
	readHeader;
	selectColumns: #( city lon );
	column: #lon as: #float.
reader next
"=> #('Firenze' 11.25)"
```

- Types: `#string`, `#integer`, `#float`, `#floatComma`, `#symbol` and `#boolean`. Numbers are exact: an integer has up to 4,300 digits, a Float is the nearest one; `nan` and `inf` are Floats.
- `converter: aBlock cached: true` evaluates the block once for each text (10,000 texts at most): for dates, times and codes, of which a file has few different ones. (10 MB of a GTFS `stop_times.txt` as objects, two times a record: 1.1 s without, 0.26 s with; NeoCSV 2.3 s, and 1.4 s with converters that keep their own Dictionary.)
- A text that is not of its type signals `SimdCSVConversionError`, which can be resumed with the value of the cell, or is given to the block of `ifInvalid:`; `nullTexts:` are texts, such as NA, that mean an empty field.

```smalltalk
(SimdCSVReader on: '1' , String lf , 'n/a' , String lf , 'x')
	nullTexts: #( 'n/a' );
	ifInvalid: [ :text :record :field | -1 ];
	addIntegerField;
	upToEnd
"=> #(#(1) #(nil) #(-1))"

[ (SimdCSVReader on: 'stop,sequence' , String lf , 'a,12abc') skipHeader; addField; addIntegerField; upToEnd ]
	on: SimdCSVConversionError
	do: [ :error | error messageText ]
"=> 'Not an integer: ''12abc'' in column sequence (field 2), record 2, line 2, character 17'"
```

Conversions, accessors and errors come when their record is reached by `next` or `do:`, never ahead. After an error the reader stands on that record: `next` signals again, `skipFailedRecord` passes it (and does nothing when no error was signalled). So this reads all the records that can be read, and the bad ones are counted; `upToEnd` instead of `do:` would lose the records before each bad one.

```smalltalk
| reader good bad |
reader := SimdCSVReader on: '1' , String lf , 'x' , String lf , '3' , String lf , 'y'.
reader addIntegerField.
good := OrderedCollection new.
bad := OrderedCollection new.
[ reader do: [ :row | good add: row first ] ]
	on: SimdCSVParseError
	do: [ :error |
		bad add: error record.
		reader skipFailedRecord.
		error retry ].
{ good asArray. bad asArray }
"=> #(#(1 3) #(2 4))"
```

```smalltalk
| reader |
reader := SimdCSVReader on: '1' , String lf , 'x' , String lf , '3'.
reader addIntegerField.
reader next.
[ reader next ] on: SimdCSVConversionError do: [ :error | reader skipFailedRecord ].
reader next
"=> #(3)"
```

## From NeoCSV

Change the name of the class: a reader on `fr readStream` takes the fast path too (the bytes of the file, not the characters of its stream).

What is different is in the table of the class comment of `SimdCSVReader`: nothing is cut when no field is declared, `12abc` is no integer, a byte order mark is skipped, a duplicate name of a Dictionary is an error, and the position of a stream is unspecified while it is read. `beStrict` checks the counts of the fields, as NeoCSV's; `beStrictQuoting` checks the quotes. `SimdCSVReader unsupportedNeoSelectors` lists what is not there.

## Tables

```smalltalk
| table |
table := SimdCSV tableFrom: 'city,lat,lon' , String lf , 'Firenze,43.77,11.25' , String lf , 'Siena,43.32,' , String lf.
{ table columnNames size. table rowCount. (table rowAt: 1) first. table at: 2 at: #city }
"=> #(3 2 'Firenze' 'Siena')"

| table |
table := SimdCSV tableFrom: 'city,lat,lon' , String lf , 'Firenze,43.77,11.25' , String lf , 'Siena,43.32,' , String lf.
table columns: #( city lon ) as: #( string float )
"=> #(#('Firenze' 'Siena') #(11.25 nil))"

((SimdCSV tableFrom: 'n' , String lf , '1.5' , String lf , '2') float64ArrayAt: #n) sum
"=> 3.5"
```

A table holds the text and 4 bytes a field. `at:at:` costs one call of the primitive: take columns for bulk (`column:`, `column:as:`, `columns:as:`, `float64ArrayAt:`).

`SimdCSV separatorOffsetsIn:` answers the index itself, what simdcsv computes: the 0-based offset of the unit that ends each field.

```smalltalk
(SimdCSV separatorOffsetsIn: 'ab,c' , String lf , 'd') asArray
"=> #(2 4 6)"
```

## Writing

```smalltalk
SimdCSV stringFrom: #( #( 'a' 'say "hi"' ) #( 1 nil ) )
"=> '""a"",""say """"hi""""""
""1"",
'"

String streamContents: [ :stream |
	(SimdCSVWriter on: stream)
		separator: $;;
		fieldWriter: #optionalQuoted;
		writeHeader: #( 'name' 'size' );
		addFields: #( #asUppercase #size );
		nextPutAll: #( 'ab' 'c;d' ) ]
"=> 'name;size
AB;2
""C;D"";3
'"
```

`SimdCSV bytesFrom:` answers UTF-8, and a binary stream gets it. `SimdCSV write:to:` takes a stream, or a FileReference whose file is replaced; a `SimdCSVWriter` takes a stream:

```smalltalk
| file |
file := FileSystem memory / 'out.csv'.
file binaryWriteStreamDo: [ :stream |
	(SimdCSVWriter on: stream)
		addRawField: #size;
		addQuotedField: #asUppercase;
		nextPutAll: #( 'ab' 'c' ) ].
file contents
"=> '2,""AB""
1,""C""
'"
```

A field has the writer of `fieldWriter:` (`#quoted`, `#optionalQuoted`, `#raw`, `#object`) or one of its own, as with `NeoCSVWriter`. An empty field (nil) is not quoted, unlike there.

Records of at least one field, each nil or a String that is not empty, read back equal with the same dialect from `#quoted` (the default) and `#optionalQuoted`; `#raw` refuses a text that would not.

## Speed

On the JIT (Xeon 6238R, Pharo 15; `docs/SimdCSV.md` of the VM has the benchmark, its gates and the other VMs), 10 MB of 10 mixed columns: `rowsFrom:` 96 MB/s (NeoCSV 11), `rowsFrom:do:` on a file 131 (10), typed rows 130 (6), 3 columns of the 10 by name 269 (11), `count:` 3.1 GB/s. Without the plugin 16 MB/s for `rowsFrom:` of 1 MB.
Rows that are all kept make old space grow, and a full garbage collection comes every one or two calls of 10 MB: called again and again `rowsFrom:` is at 44 MB/s (NeoCSV 10). `do:` makes none, whatever the size of the file (2 GB: 15 s, nothing retained). Sources of one or two short lines are read 1.4 to 2 times as slowly as by NeoCSV, from three lines on faster. Converters without `cached:` and Floats of 17 digits are the work of the image. The writer is in Smalltalk: at 1 MB 0.9 times as fast as NeoCSV's when every field is quoted and 1.7 times with `#optionalQuoted`, at 10 MB 0.5 and 1.5 times; with characters beyond U+00FF in every record 0.5 and 1.3 times at 1 MB.

## Limits

A record has at most 64 MiB (`maxRecordBytes:`) and 65,536 fields (`maxFields:`), a table at most 4,294,967,294 units and an index of 1 GiB (`SimdCSVTable maxIndexBytes:`); 16 MiB and 256 MiB in WebAssembly and in a VM whose old space is bounded (its parameter 67): `SimdCSVResourceError` says which was passed, and where a quote was left open. A reader reads sources of any size.

There are no comments, escape characters, trimmed spaces, separators of several characters or encodings other than UTF-8 and Latin-1 (decode the text first).

## Backend

```smalltalk
#( #plugin #smalltalk ) includes: SimdCSV backend
"=> true"

#( 'avx2' 'sse2' 'neon' 'fallback' 'smalltalk' ) includes: SimdCSV implementationName
"=> true"
```

`SimdCSV pluginInfo` is what the plugin says of itself, or nil. Set `SIMDCSV_FORCE_IMPLEMENTATION` (`avx2`, `sse2`, `neon`, `fallback`) in the environment to choose the kernel.

## Licence

MIT, see `LICENSE`. The plugin includes code of simdcsv (Apache License 2.0), which is not in this repository.
