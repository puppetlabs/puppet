require 'puppet/parser/script_compiler'

module Puppet::Pops
module Evaluator

# Utility class to help resolve instances of Puppet::Pops::Types::PDeferredType::Deferred
#
class DeferredResolver
  DOLLAR = '$'.freeze
  DIG    = 'dig'.freeze

  # Resolves and replaces all Deferred values in a catalog's resource attributes
  # found as direct values or nested inside Array, Hash or Sensitive values.
  # Deferred values inside of custom Object instances are not resolved as this
  # is expected to be done by such objects.
  #
  # @param facts [Puppet::Node::Facts] the facts object for the node
  # @param catalog [Puppet::Resource::Catalog] the catalog where all deferred values should be replaced
  # @return [nil] does not return anything - the catalog is modified as a side effect
  #
  def self.resolve_and_replace(facts, catalog)
    compiler = Puppet::Parser::ScriptCompiler.new(catalog.environment_instance, catalog.name, true)
    resolver = new(compiler)
    resolver.set_facts_variable(facts)
    # TODO:
    #    # When scripting the trusted data are always local, but set them anyway
    #    @scope.set_trusted(node.trusted_data)
    #
    #    # Server facts are always about the local node's version etc.
    #    @scope.set_server_facts(node.server_facts)

    resolver.resolve_futures(catalog)
    nil
  end

  # Resolves a value such that a direct Deferred, or any nested Deferred values
  # are resolved and used instead of the deferred value.
  # A direct Deferred value, or nested deferred values inside of Array, Hash or
  # Sensitive values are resolved and replaced inside of freshly created
  # containers.
  #
  # The resolution takes place in the topscope of the given compiler.
  # Variable values are supposed to already have been set.
  #
  # @param value [Object] the (possibly nested) value to resolve
  # @param compiler [Puppet::Parser::ScriptCompiler, Puppet::Parser::Compiler] the compiler in effect
  # @return [Object] the resolved value (a new Array, Hash, or Sensitive if needed), with all deferred values resolved
  #
  def self.resolve(value, compiler)
    resolver = new(compiler)
    resolver.resolve(value)
  end

  def initialize(compiler)
    @compiler = compiler
    # Always resolve in top scope
    @scope = @compiler.topscope
    @deferred_class = Puppet::Pops::Types::TypeFactory.deferred.implementation_class
  end

  # @param facts [Puppet::Node::Facts] the facts to set in $facts in the compiler's topscope
  #
  def set_facts_variable(facts)
    @scope.set_facts(facts.nil? ? {} : facts.values)
  end

  def resolve_futures(catalog)
    catalog.resources.each do |r|
      overrides = {}
      r.parameters.each_pair do |k, v|
        resolved = resolve(v)
        # If the value is instance of Sensitive - assign the unwrapped value
        # and mark it as sensitive if not already marked
        #
        if resolved.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
          resolved = resolved.unwrap
          unless r.sensitive_parameters.include?(k.to_sym)
            r.sensitive_parameters = (r.sensitive_parameters + [k.to_sym]).freeze
          end
        end
        overrides[ k ] = resolved
      end
      r.parameters.merge!(overrides) unless overrides.empty?
    end
  end

  def resolve(x)
    if x.class == @deferred_class
      resolve_future(x)
    elsif x.is_a?(Array)
      x.map {|v| resolve(v) }
    elsif x.is_a?(Hash)
      result = {}
      x.each_pair {|k,v| result[k] = resolve(v) }
      result
    elsif x.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
      # rewrap in a new Sensitive after resolving any nested deferred values
      Puppet::Pops::Types::PSensitiveType::Sensitive.new(resolve(x.unwrap))
    elsif x.is_a?(Puppet::Pops::Types::PBinaryType::Binary)
      # use the ASCII-8BIT string that it wraps
      x.binary_buffer
    else
      x
    end
  end

  def resolve_future(f)
    # If any of the arguments to a future is a future it needs to be resolved first
    func_name = f.name
    mapped_arguments = map_arguments(f.arguments)
    # if name starts with $ then this is a call to dig 
    if func_name[0] == DOLLAR
      var_name = func_name[1..-1]
      func_name = DIG
      mapped_arguments.insert(0, @scope[var_name])
    end

    # call the function (name in deferred, or 'dig' for a variable)
    @scope.call_function(func_name, mapped_arguments)
  end

  def map_arguments(args)
    return [] if args.nil?
    args.map {|v| resolve(v) }
  end
  private :map_arguments

end
end
end
