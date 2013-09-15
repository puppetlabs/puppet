
module PuppetSpec::Scope
  # Initialize a new scope suitable for testing.
  #
  def create_test_scope_for_node(node_name)
    node = Puppet::Node.new(node_name)
    compiler = Puppet::Parser::Compiler.new(node)
    scope = Puppet::Parser::Scope.new(compiler)
    scope.source = Puppet::Resource::Type.new(:node, node_name)
    scope.parent = compiler.topscope
    scope
  end

end