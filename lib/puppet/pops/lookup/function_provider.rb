require_relative 'data_adapter'
require_relative 'context'
require_relative 'data_provider'

module Puppet::Pops
module Lookup
# @api private
class FunctionProvider
  include DataProvider

  attr_reader :parent_data_provider, :function_name, :locations

  def initialize(name, parent_data_provider, function_name, options, locations)
    @name = name
    @parent_data_provider = parent_data_provider
    @function_name = function_name
    @options = options
    @locations = locations || [nil]
    @contexts = {}
  end

  # @return [FunctionContext] the function context associated with this provider
  def function_context(lookup_invocation, location)
    scope = lookup_invocation.scope
    compiler = scope.compiler
    @contexts[location] ||= FunctionContext.new(compiler.environment.name, module_name, function(scope))
  end

  def module_name
    @parent_data_provider.module_name
  end

  def name
    "Hierarchy entry \"#{@name}\""
  end

  def to_s
    name
  end

  # Obtains the options to send to the function, optionally merged with a 'path' or 'uri' option
  #
  # @param [Pathname,URI] location The location to add to the options
  # @return [Hash{String => Object}] The options hash
  def options(location = nil)
    case location
    when nil
      @options
    when Pathname
      @options.merge(HieraConfig::KEY_PATH => location.to_s)
    when URI
      @options.merge(HieraConfig::KEY_URI => location.to_s)
    else
      @options
    end
  end

  private

  def function(scope)
    @function ||= load_function(scope)
  end

  def load_function(scope)
    loaders = scope.compiler.loaders
    typed_name = Loader::TypedName.new(:function, @function_name)
    loader = if typed_name.qualified?
      qualifier = typed_name.name_parts[0]
      qualifier == 'environment' ? loaders.private_environment_loader : loaders.private_loader_for_module(qualifier)
    else
      loaders.private_environment_loader
    end
    te = loader.load_typed(typed_name)
    if te.nil? || te.value.nil?
      raise Puppet::DataBinding::LookupError,
        "#{@options[HieraConfig::KEY_NAME]}: Unable to find '#{self.class::TAG}' function named '#{function_name}'"
    end
    te.value
  end
end
end
end
