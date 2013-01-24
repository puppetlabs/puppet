module PuppetSpec::Compiler
  def compile_to_catalog(string, node = Puppet::Node.new('foonode'))
    Puppet[:code] = string
    Puppet::Parser::Compiler.compile(node)
  end
end
