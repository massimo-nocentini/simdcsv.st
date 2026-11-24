# simdcsv.st

CSV for Pharo 12, 13, 14 and 15, with [simdcsv](https://github.com/geofflangdale/simdcsv) in the `SimdCSVPlugin` of the VM
(`plugins/SimdCSVPlugin` and `docs/SimdCSV.md` of https://github.com/massimo-nocentini/pharo-vm). Without the plugin the
same answers come from pure Smalltalk.

```smalltalk
Metacello new
	baseline: 'SimdCSV';
	repository: 'github://massimo-nocentini/simdcsv.st:master/src';
	load
```

Licence: MIT.
