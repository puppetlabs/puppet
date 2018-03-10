class Puppet::Parser::AST::Node < Puppet::Parser::AST::TopLevelConstruct
  attr_accessor :names, :context

  def initialize(names, context = {})
    raise ArgumentError, _("names should be an array") unless names.is_a? Array
    if context[:parent]
      raise Puppet::DevError, _("Node inheritance is removed in Puppet 4.0.0. See http://links.puppet.com/puppet-node-inheritance-deprecation")
    end

    @names = names
    @context = context
  end

  def instantiate(modname)
    @names.map { |name| Puppet::Resource::Type.new(:node, name, @context.merge(:module_name => modname)) }
  end
end
