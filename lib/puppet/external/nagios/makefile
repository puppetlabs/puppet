all: parser.rb

debug: parser.rb setdebug

parser.rb: grammar.ry
	racc -oparser.rb grammar.ry

setdebug:
	perl -pi -e 's{\@yydebug =.*$$}{\@yydebug = true}' parser.rb
