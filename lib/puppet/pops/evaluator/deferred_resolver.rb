# frozen_string_literal: true

require_relative '../../../puppet/parser/script_compiler'

module Puppet::Pops
module Evaluator
class DeferredValue
  def initialize(proc)
    @proc = proc
  end

  def resolve
    val = @proc.call
    # Deferred sensitive values will be marked as such in resolve_futures()
    if val.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
      val.unwrap
    else
      val
    end
  end
end

# Utility class to help resolve instances of Puppet::Pops::Types::PDeferredType::Deferred
#
class DeferredResolver
  DOLLAR = '$'
  DIG    = 'dig'

  # Resolves and replaces all Deferred values in a catalog's resource attributes
  # found as direct values or nested inside Array, Hash or Sensitive values.
  # Deferred values inside of custom Object instances are not resolved as this
  # is expected to be done by such objects.
  #
  # @param facts [Puppet::Node::Facts] the facts object for the node
  # @param catalog [Puppet::Resource::Catalog] the catalog where all deferred values should be replaced
  # @param environment [Puppet::Node::Environment] the environment whose anonymous module methods
  #  are to be mixed into the scope
  # @return [nil] does not return anything - the catalog is modified as a side effect
  #
  def self.resolve_and_replace(facts, catalog, environment = catalog.environment_instance, preprocess_deferred = true)
    compiler = Puppet::Parser::ScriptCompiler.new(environment, catalog.name, preprocess_deferred)
    resolver = new(compiler, preprocess_deferred)
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

  def initialize(compiler, preprocess_deferred = true)
    @compiler = compiler
    # Always resolve in top scope
    @scope = @compiler.topscope
    @deferred_class = Puppet::Pops::Types::TypeFactory.deferred.implementation_class
    @preprocess_deferred = preprocess_deferred
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
        case resolved
        when Puppet::Pops::Types::PSensitiveType::Sensitive
          resolved = resolved.unwrap
          mark_sensitive_parameters(r, k)
        # If the value is a DeferredValue and it has an argument of type PSensitiveType, mark it as sensitive
        # The DeferredValue.resolve method will unwrap it during catalog application
        when Puppet::Pops::Evaluator::DeferredValue
          if v.arguments.any? { |arg| arg.is_a?(Puppet::Pops::Types::PSensitiveType) }
            mark_sensitive_parameters(r, k)
          end
        end
        overrides[k] = resolved
      end
      r.parameters.merge!(overrides) unless overrides.empty?
    end
  end

  def mark_sensitive_parameters(r, k)
    unless r.sensitive_parameters.include?(k.to_sym)
      r.sensitive_parameters = (r.sensitive_parameters + [k.to_sym]).freeze
    end
  end
  private :mark_sensitive_parameters

  def resolve(x)
    if x.instance_of?(@deferred_class)
      resolve_future(x)
    elsif x.is_a?(Array)
      x.map { |v| resolve(v) }
    elsif x.is_a?(Hash)
      result = {}
      x.each_pair { |k, v| result[k] = resolve(v) }
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

  def resolve_lazy_args(x)
    case x
    when DeferredValue
      x.resolve
    when Array
      x.map { |v| resolve_lazy_args(v) }
    when Hash
      result = {}
      x.each_pair { |k, v| result[k] = resolve_lazy_args(v) }
      result
    when Puppet::Pops::Types::PSensitiveType::Sensitive
      # rewrap in a new Sensitive after resolving any nested deferred values
      Puppet::Pops::Types::PSensitiveType::Sensitive.new(resolve_lazy_args(x.unwrap))
    else
      x
    end
  end
  private :resolve_lazy_args

  def resolve_future(f)
    # If any of the arguments to a future is a future it needs to be resolved first
    func_name = f.name
    mapped_arguments = map_arguments(f.arguments)
    # if name starts with $ then this is a call to dig
    if func_name[0] == DOLLAR
      var_name = func_name[1..]
      func_name = DIG
      mapped_arguments.insert(0, @scope[var_name])
    end

    if @preprocess_deferred
      # call the function (name in deferred, or 'dig' for a variable)
      @scope.call_function(func_name, mapped_arguments)
    else
      # call the function later
      DeferredValue.new(
        proc {
          # deferred functions can have nested deferred arguments
          resolved_arguments = mapped_arguments.map { |arg| resolve_lazy_args(arg) }
          @scope.call_function(func_name, resolved_arguments)
        }
      )
    end
  end

  def map_arguments(args)
    return [] if args.nil?

    args.map { |v| resolve(v) }
  end
  private :map_arguments
end
end
end
