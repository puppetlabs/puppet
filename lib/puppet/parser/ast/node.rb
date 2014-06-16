require 'puppet/parser/ast/top_level_construct'

class Puppet::Parser::AST::Node < Puppet::Parser::AST::TopLevelConstruct
  attr_accessor :names, :context

  def initialize(names, context = {}, &ruby_code)
    raise ArgumentError, "names should be an array" unless names.is_a? Array
    if context[:parent]
      msg = "Deprecation notice: Node inheritance is not supported in Puppet >= 4.0.0. See http://links.puppetlabs.com/puppet-node-inheritance-deprecation"
      Puppet.puppet_deprecation_warning(msg, :key => "node-inheritance-#{names.join}", :file => context[:file], :line => context[:line])
    end

    @names = names
    @context = context
    @ruby_code = ruby_code
  end

  def instantiate(modname)
    @names.collect do |name|
      new_node = Puppet::Resource::Type.new(:node, name, @context.merge(:module_name => modname))
      new_node.ruby_code = @ruby_code if @ruby_code
      new_node
    end
  end
end
