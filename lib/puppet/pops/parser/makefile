
eparser.rb: egrammar.ra
	racc -o$@ egrammar.ra

egrammar.output: egrammar.ra
	racc -v -o$@ egrammar.ra

egrammar.debug: egrammar.ra
	racc -t -oeparser.rb egrammar.ra

