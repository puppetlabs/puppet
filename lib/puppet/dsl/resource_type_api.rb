require 'puppet/resource/type'

# Type of the objects inside of which pure ruby manifest files are
# executed.  Provides methods for creating defines, hostclasses, and
# nodes.
class Puppet::DSL::ResourceTypeAPI
  def initialize
    @__created_ast_objects__ = []
  end

  def define(name, *args, &block)
    args = args.inject([]) do |result, item|
      if item.is_a?(Hash)
        item.each { |p, v| result << [p, v] }
      else
        result << item
      end
      result
    end
    @__created_ast_objects__.push Puppet::Parser::AST::Definition.new(name, {:arguments => args}, &block)
    nil
  end

  def hostclass(name, options = {}, &block)
    @__created_ast_objects__.push Puppet::Parser::AST::Hostclass.new(name, options, &block)
    nil
  end

  def node(name, options = {}, &block)
    name = [name] unless name.is_a?(Array)
    @__created_ast_objects__.push Puppet::Parser::AST::Node.new(name, options, &block)
    nil
  end
end
