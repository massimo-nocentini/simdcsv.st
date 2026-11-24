"
I read generated files in the manner of GTFS (stops, routes, trips, stop times, connections and requests of public transport) with the readers of an application that uses NeoCSVReader, in which only the name of the class was changed.
"
Class {
	#name : 'SimdCSVGTFSTest',
	#superclass : 'SimdCSVReadingTestCase',
	#category : 'SimdCSV-Tests-Tests',
	#package : 'SimdCSV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SimdCSVGTFSTest >> fileNamed: aString with: lines [
	| file |
	file := FileSystem memory / aString.
	file writeStreamDo: [ :stream | stream nextPutAll: (String crlf join: lines) ].
	^ file
]

{ #category : 'helpers' }
SimdCSVGTFSTest >> assertBytes: aReader [
	"The fast path was taken"

	self assert: (aReader instVarNamed: #input) isBytes
]

{ #category : 'helpers' }
SimdCSVGTFSTest >> time: seconds [
	"As in GTFS, hours may be beyond 23"

	^ String streamContents: [ :stream |
		  #( 3600 60 1 ) with: #( 24 60 60 ) do: [ :unit :base |
			  | value |
			  value := seconds // unit.
			  unit < 3600 ifTrue: [ value := value \\ base ].
			  value < 10 ifTrue: [ stream nextPut: $0 ].
			  stream print: value.
			  unit > 1 ifTrue: [ stream nextPut: $: ] ] ]
]

{ #category : 'tests' }
SimdCSVGTFSTest >> testRoutes [
	| fr reader routes |
	fr := self fileNamed: 'routes.txt' with: #( 'route_id,agency_id,route_short_name,route_long_name,route_type' '1,A,C1,"Fortezza, Duomo",3' '2,A,,Lungarno,3' ).
	reader := SimdCSVReader on: fr readStream.
	routes := reader
		          skipHeader;
		          recordClass: SimdCSVTestRecord;
		          addField: #x:;
		          addIgnoredField;
		          addField: #y:;
		          addField: #z:;
		          upToEnd.
	self assert: routes equals: { (SimdCSVTestRecord x: '1' y: 'C1' z: 'Fortezza, Duomo'). (SimdCSVTestRecord x: '2' y: nil z: 'Lungarno') }.
	self assertBytes: reader
]

{ #category : 'tests' }
SimdCSVGTFSTest >> testTrips [
	| fr reader trips |
	fr := self fileNamed: 'trips.txt' with: #( 'route_id,service_id,trip_id,trip_headsign,direction_id,shape_id' '1,S,T1,Duomo,0,x' '1,S,T2,Università,1,' ).
	reader := SimdCSVReader on: fr readStream.
	trips := reader
		         skipHeader;
		         recordClass: SimdCSVTestRecord;
		         addField: #x:;
		         addIgnoredField;
		         addField: #y:;
		         addField: #z:;
		         addIgnoredField;
		         addIgnoredField;
		         upToEnd.
	self assert: trips equals: { (SimdCSVTestRecord x: '1' y: 'T1' z: 'Duomo'). (SimdCSVTestRecord x: '1' y: 'T2' z: 'Università') }.
	self assertBytes: reader
]

{ #category : 'tests' }
SimdCSVGTFSTest >> testStops [
	| fr reader stops |
	fr := self fileNamed: 'stops.txt' with: #( 'stop_id,stop_name,stop_lat,stop_lon,stop_code' 'S1,"Piazza ""Indipendenza""",43.7767,11.2491,FI01' 'S2,Via Nazionale,43.770001256270125,11.25,' ).
	reader := SimdCSVReader on: fr readStream.
	stops := reader
		         skipHeader;
		         recordClass: Dictionary;
		         addFieldAt: #id;
		         addFieldAt: #name;
		         addFloatFieldAt: #latitude;
		         addFloatFieldAt: #longitude;
		         addFieldAt: #code;
		         upToEnd.
	self assert: (stops first at: #name) equals: 'Piazza "Indipendenza"'.
	self assert: (stops collect: [ :each | each at: #latitude ]) equals: #( 43.7767 43.770001256270125 ).
	self assert: (stops collect: [ :each | each at: #code ifAbsent: [ 'none' ] ]) equals: #( 'FI01' 'none' ).
	self assertBytes: reader
]

{ #category : 'tests' }
SimdCSVGTFSTest >> testStopTimes [
	| fr reader converter stopTimes count lines |
	count := self largeSize: 5000.
	lines := OrderedCollection with: 'trip_id,arrival_time,departure_time,stop_id,stop_sequence,shape_dist_traveled'.
	0 to: count - 1 do: [ :i |
		lines add: (',' join: {
					 ('T' , (i // 20) printString).
					 (self time: 18000 + (i \\ 20 * 90) + (i // 20 * 600)).
					 (self time: 18010 + (i \\ 20 * 90) + (i // 20 * 600)).
					 ('S' , (i \\ 20) printString).
					 (i \\ 20 + 1) printString.
					 (i \\ 7 = 0
						  ifTrue: [ '' ]
						  ifFalse: [ (i \\ 20 * 350) asString ]) }) ].
	fr := self fileNamed: 'stop_times.txt' with: lines.
	converter := [ :aString |
	             | parts |
	             parts := aString substrings: ':'.
	             parts inject: 0 into: [ :sum :part | sum * 60 + part asInteger ] ].
	{ [ reader addField: [ :record :value | record at: #arrival put: value ] converter: converter ].
	  [ reader addField: [ :record :value | record at: #arrival put: value ] converter: converter cached: true ] } do: [ :arrival |
		reader := SimdCSVReader on: fr readStream.
		reader
			skipHeader;
			recordClass: Dictionary;
			addFieldAt: #trip.
		arrival value.
		stopTimes := reader
			             addFieldAt: #departure converter: converter;
			             addFieldAt: #stop;
			             addIntegerFieldAt: #sequence;
			             addFieldAt: #distance;
			             upToEnd.
		self assert: stopTimes size equals: count.
		stopTimes withIndexDo: [ :each :i |
			self assert: (each at: #trip) equals: 'T' , (i - 1 // 20) printString.
			self assert: (each at: #arrival) equals: 18000 + (i - 1 \\ 20 * 90) + (i - 1 // 20 * 600).
			self assert: (each at: #departure) equals: (each at: #arrival) + 10.
			self assert: (each at: #sequence) equals: i - 1 \\ 20 + 1.
			self assert: (each includesKey: #distance) equals: i - 1 \\ 7 ~= 0 ].
		self assertBytes: reader ]
]

{ #category : 'tests' }
SimdCSVGTFSTest >> testConnections [
	| fr reader edges |
	fr := self fileNamed: 'network_combined.csv' with: #( 'from_stop_I;to_stop_I;dep_time_ut;arr_time_ut;route_type;trip_I;seq;route_I' '1;2;1481513100;1481513160;3;77;1;5' '2;3;1481513160;1481513280;3;77;2;5' ).
	reader := SimdCSVReader on: fr readStream.
	edges := reader
		         separator: $;;
		         skipHeader;
		         recordClass: OrderedCollection;
		         addField: [ :edge :value | edge add: value ];
		         addField: [ :edge :value | edge add: value ];
		         addIntegerField: [ :edge :value | edge add: value ];
		         addIntegerField: [ :edge :value | edge add: value ];
		         addIntegerField: [ :edge :value | edge add: value ];
		         addField: [ :edge :value | edge add: value ];
		         addIntegerField: [ :edge :value | edge add: value ];
		         addField: [ :edge :value | edge add: value ];
		         upToEnd.
	self assert: edges first asArray equals: #( '1' '2' 1481513100 1481513160 3 '77' 1 '5' ).
	self assert: edges size equals: 2.
	self assertBytes: reader
]

{ #category : 'tests' }
SimdCSVGTFSTest >> testRequests [
	| fr reader requests |
	fr := self fileNamed: 'requests.csv' with: #( 'from;to;unix_time;multiplicity' 'S1;S2;1481513100;2' 'S2;S1;1481520000;1' ).
	reader := SimdCSVReader on: fr readStream.
	requests := reader
		            separator: $;;
		            skipHeader;
		            recordClass: SimdCSVTestRecord;
		            addField: #x:;
		            addField: #y:;
		            addIntegerField: #z:;
		            addIntegerField: [ :record :value | record x: record x -> value ];
		            upToEnd.
	self assert: requests first equals: (SimdCSVTestRecord x: 'S1' -> 2 y: 'S2' z: 1481513100).
	self assertBytes: reader
]
