# Puppet "parser" for the rdoc system
# The parser uses puppet parser and traverse the AST to instruct RDoc about
# our current structures. It also parses ruby files that could contain
# either custom facts or puppet plugins (functions, types...)

# rdoc2 includes
require "rdoc/code_objects"
require "puppet/util/rdoc/code_objects"
require "rdoc/token_stream"
require "rdoc/markup/pre_process"
require "rdoc/parser"
require "puppet/util/rdoc/parser/puppet_parser_rdoc2.rb"
