module PuppetSpec::Compiler
  def compile_to_catalog(string)
    Puppet[:code] = string
    Puppet::Parser::Compiler.compile(Puppet::Node.new('foonode'))
  end
end
