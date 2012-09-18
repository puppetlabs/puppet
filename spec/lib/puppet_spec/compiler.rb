module PuppetSpec::Compiler
  def compile_to_catalog(string, node = Puppet::Node.new('foonode'))
    Puppet[:code] = string
    Puppet::Parser::Compiler.compile(node)
  end

  def compile_ruby_to_catalog(string = nil, node = Puppet::Node.new('foonode'))
    File.stubs(:open).yields(StringIO.new(string))
    Puppet::Parser::Compiler.compile(node)
  end

  def prepare_compiler
    let(:compiler) { Puppet::Parser::Compiler.new(Puppet::Node.new("floppy", :environment => 'production')) }
    let(:scope)    { Puppet::Parser::Scope.new compiler }
  end

end
