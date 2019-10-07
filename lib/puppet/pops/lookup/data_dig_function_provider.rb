require_relative 'function_provider'

module Puppet::Pops
module Lookup
# @api private
class DataDigFunctionProvider < FunctionProvider
  TAG = 'data_dig'.freeze

  # Performs a lookup with the assumption that a recursive check has been made.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String => Object},nil] Merge strategy, merge strategy name, strategy and options hash, or nil (implies "first found")
  # @return [Object] the found object
  # @throw :no_such_key when the object is not found
  def unchecked_key_lookup(key, lookup_invocation, merge)
    lookup_invocation.with(:data_provider, self) do
      MergeStrategy.strategy(merge).lookup(locations, lookup_invocation) do |location|
        invoke_with_location(lookup_invocation, location, key, merge)
      end
    end
  end

  def invoke_with_location(lookup_invocation, location, key, merge)
    if location.nil?
      key.undig(lookup_invocation.report_found(key, validated_data_dig(key, lookup_invocation, nil, merge)))
    else
      lookup_invocation.with(:location, location) do
        key.undig(lookup_invocation.report_found(key, validated_data_dig(key, lookup_invocation, location, merge)))
      end
    end
  end

  def label
    'Data Dig'
  end

  def validated_data_dig(key, lookup_invocation, location, merge)
    validate_data_value(data_dig(key, lookup_invocation, location, merge)) do
      msg = "Value for key '#{key}', returned from #{full_name}"
      location.nil? ? msg : "#{msg}, when using location '#{location}',"
    end
  end

  private

  def data_dig(key, lookup_invocation, location, merge)
    unless location.nil? || location.exist?
      lookup_invocation.report_location_not_found
      throw :no_such_key
    end
    ctx = function_context(lookup_invocation, location)
    ctx.data_hash ||= {}
    catch(:no_such_key) do
      hash = ctx.data_hash
      hash[key] = ctx.function.call(lookup_invocation.scope, key.to_a, options(location), Context.new(ctx, lookup_invocation)) unless hash.include?(key)
      return hash[key]
    end
    lookup_invocation.report_not_found(key)
    throw :no_such_key
  end
end

# @api private
class V3BackendFunctionProvider < DataDigFunctionProvider
  TAG = 'hiera3_backend'.freeze

  def data_dig(key, lookup_invocation, location, merge)
    @backend ||= instantiate_backend(lookup_invocation)

    # A merge_behavior retrieved from hiera.yaml must not be converted here. Instead, passing the symbol :hash
    # tells the V3 backend to pick it up from the config.
    resolution_type = lookup_invocation.hiera_v3_merge_behavior? ? :hash : convert_merge(merge)
    @backend.lookup(key.to_s, lookup_invocation.scope, lookup_invocation.hiera_v3_location_overrides, resolution_type, {:recurse_guard => nil})
  end

  def full_name
    "hiera version 3 backend '#{options[HieraConfig::KEY_BACKEND]}'"
  end

  def value_is_validated?
    false
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
