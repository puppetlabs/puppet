require_relative 'function_provider'

module Puppet::Pops
module Lookup
# @api private
class LookupKeyFunctionProvider < FunctionProvider
  TAG = 'lookup_key'.freeze

  # Performs a lookup with the assumption that a recursive check has been made.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String => Object},nil] Merge strategy, merge strategy name, strategy and options hash, or nil (implies "first found")
  # @return [Object] the found object
  # @throw :no_such_key when the object is not found
  def unchecked_key_lookup(key, lookup_invocation, merge)
    root_key = key.root_key
    lookup_invocation.with(:data_provider, self) do
      MergeStrategy.strategy(merge).lookup(locations, lookup_invocation) do |location|
        invoke_with_location(lookup_invocation, location, root_key, merge)
      end
    end
  end

  def invoke_with_location(lookup_invocation, location, root_key, merge)
    if location.nil?
      value = lookup_key(root_key, lookup_invocation, nil, merge)
      lookup_invocation.report_found(root_key, validate_data_value(self, value))
    else
      lookup_invocation.with(:location, location) do
        value = lookup_key(root_key, lookup_invocation, location.location, merge)
        lookup_invocation.report_found(root_key, validate_data_value(self, value))
      end
    end
  end

  def label
    'Lookup Key'
  end

  private

  def lookup_key(key, lookup_invocation, location, merge)
    unless location.nil? || location.exist?
      lookup_invocation.report_location_not_found
      throw :no_such_key
    end
    ctx = function_context(lookup_invocation, location)
    ctx.data_hash ||= {}
    catch(:no_such_key) do
      hash = ctx.data_hash
      hash[key] = ctx.function.call(lookup_invocation.scope, key, options(location), Context.new(ctx, lookup_invocation)) unless hash.include?(key)
      return hash[key]
    end
    lookup_invocation.report_not_found(key)
    throw :no_such_key
  end
end

# @api private
class V3LookupKeyFunctionProvider < LookupKeyFunctionProvider
  TAG = 'v3_lookup_key'.freeze

  def initialize(name, parent_data_provider, function_name, options, locations)
    @datadir = options.delete(HieraConfig::KEY_DATADIR)
    super
  end

  def unchecked_key_lookup(key, lookup_invocation, merge)
    extra_paths = lookup_invocation.hiera_v3_location_overrides
    if extra_paths.nil? || extra_paths.empty?
      super
    else
      # Extra paths provided. Must be resolved and placed in front of known paths
      paths = parent_data_provider.config(lookup_invocation).resolve_paths(@datadir, extra_paths, lookup_invocation, false, ".#{@name}")
      all_locations = paths + locations
      root_key = key.root_key
      lookup_invocation.with(:data_provider, self) do
        MergeStrategy.strategy(merge).lookup(all_locations, lookup_invocation) do |location|
          invoke_with_location(lookup_invocation, location, root_key, merge)
        end
      end
    end
  end
end

class V3BackendFunctionProvider < LookupKeyFunctionProvider
  TAG = 'hiera3_backend'.freeze

  def lookup_key(key, lookup_invocation, location, merge)
    @backend ||= instantiate_backend(lookup_invocation)
    @backend.lookup(key, lookup_invocation.scope, lookup_invocation.hiera_v3_location_overrides, convert_merge(merge), context = {:recurse_guard => nil})
  end

  private

  def instantiate_backend(lookup_invocation)
    backend_name = options[HieraConfig::KEY_BACKEND]
    begin
      require 'hiera/backend'
      require "hiera/backend/#{backend_name.downcase}_backend"
      backend = Hiera::Backend.const_get("#{backend_name.capitalize}_backend").new
      return backend.method(:lookup).arity == 4 ? Hiera::Backend::Backend1xWrapper.new(backend) : backend
    rescue LoadError => e
      lookup_invocation.report_text { "Unable to load backend '#{backend_name}': #{e.message}" }
      throw :no_such_key
    rescue NameError => e
      lookup_invocation.report_text { "Unable to instantiate backend '#{backend_name}': #{e.message}" }
      throw :no_such_key
    end
  end

  # Converts a lookup 'merge' parameter argument into a Hiera 'resolution_type' argument.
  #
  # @param merge [String,Hash,nil] The lookup 'merge' argument
  # @return [Symbol,Hash,nil] The Hiera 'resolution_type'
  def convert_merge(merge)
    case merge
    when nil
    when 'first', 'default'
      # Nil is OK. Defaults to Hiera :priority
      nil
    when Puppet::Pops::MergeStrategy
      convert_merge(merge.configuration)
    when 'unique'
      # Equivalent to Hiera :array
      :array
    when 'hash'
      # Equivalent to Hiera :hash with default :native merge behavior. A Hash must be passed here
      # to override possible Hiera deep merge config settings.
      { :behavior => :native }
    when 'deep', 'unconstrained_deep'
      # Equivalent to Hiera :hash with :deeper merge behavior.
      { :behavior => :deeper }
    when 'reverse_deep'
      # Equivalent to Hiera :hash with :deep merge behavior.
      { :behavior => :deep }
    when Hash
      strategy = merge['strategy']
      case strategy
      when 'deep', 'unconstrained_deep', 'reverse_deep'
        result = { :behavior => strategy == 'reverse_deep' ? :deep : :deeper }
        # Remaining entries must have symbolic keys
        merge.each_pair { |k,v| result[k.to_sym] = v unless k == 'strategy' }
        result
      else
        convert_merge(strategy)
      end
    else
      raise Puppet::DataBinding::LookupError, "Unrecognized value for request 'merge' parameter: '#{merge}'"
    end
  end
end
end
end
