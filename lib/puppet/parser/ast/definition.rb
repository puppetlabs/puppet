require 'puppet/parser/ast/top_level_construct'

class Puppet::Parser::AST::Definition < Puppet::Parser::AST::TopLevelConstruct
  attr_accessor :context

  def initialize(name, context = {}, &ruby_code)
    @name = name
    @context = context
  end

  def instantiate(modname)
    [Puppet::Resource::Type.new(:definition, @name, @context.merge(:module_name => modname))]
  end
end
