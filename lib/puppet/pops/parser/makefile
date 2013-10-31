
#parser.rb: grammar.ra
#	racc -o$@ grammar.ra
#
#grammar.output: grammar.ra
#	racc -v -o$@ grammar.ra
#

eparser.rb: egrammar.ra
	racc  -o$@ egrammar.ra

# debugging parser (also turn on @@yydebug, and set @racc_debug_out
# eparser.rb: egrammar.ra
#	racc -g -o$@ egrammar.ra

egrammar.output: egrammar.ra
	racc -v -o$@ egrammar.ra
