
desc "Generate the parser"
task :gen_parser do
  %x{racc -olib/puppet/parser/parser.rb lib/puppet/parser/grammar.ra}
end
