desc "Generate the 4.x 'future' parser"
task :gen_eparser => :require_racc do
  %x{racc -olib/puppet/pops/parser/eparser.rb lib/puppet/pops/parser/egrammar.ra}
end

desc "Generate the 4.x 'future' parser with egrammar.output"
task :gen_eparser_output => :require_racc do
  %x{racc -v -olib/puppet/pops/parser/eparser.rb lib/puppet/pops/parser/egrammar.ra}
end

desc "Generate the 4.x 'future' parser with debugging output"
task :gen_eparser_debug => :require_racc do
  %x{racc -t -olib/puppet/pops/parser/eparser.rb lib/puppet/pops/parser/egrammar.ra}
end

task :require_racc do
  begin
    require 'racc'
  rescue LoadError
    abort("Run `bundle install --with development` to install the `racc` gem.")
  end
end
