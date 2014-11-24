desc "Generate the 4.x 'future' parser"
task :gen_eparser do
  %x{racc -olib/puppet/pops/parser/eparser.rb lib/puppet/pops/parser/egrammar.ra}
end

desc "Generate the 4.x 'future' parser with egrammar.output"
task :gen_eparser_output do
  %x{racc -v -olib/puppet/pops/parser/eparser.rb lib/puppet/pops/parser/egrammar.ra}
end

desc "Generate the 4.x 'future' parser with debugging output"
task :gen_eparser_debug do
  %x{racc -t -olib/puppet/pops/parser/eparser.rb lib/puppet/pops/parser/egrammar.ra}
end
