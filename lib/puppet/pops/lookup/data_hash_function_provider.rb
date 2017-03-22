require_relative 'function_provider'
require_relative 'interpolation'

module Puppet::Pops
module Lookup
# @api private
class DataHashFunctionProvider < FunctionProvider
  include SubLookup
  include Interpolation

  TAG = 'data_hash'.freeze

  def self.trusted_return_type
    @trusted_return_type ||= Types::PHashType.new(DataProvider.key_type, DataProvider.value_type)
  end

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
        invoke_with_location(lookup_invocation, location, root_key)
      end
    end
  end

  private

  def invoke_with_location(lookup_invocation, location, root_key)
    if location.nil?
      lookup_key(lookup_invocation, nil, root_key)
    else
      lookup_invocation.with(:location, location) do
        if location.exist?
          lookup_key(lookup_invocation, location, root_key)
        else
          lookup_invocation.report_location_not_found
          throw :no_such_key
        end
      end
    end
  end

  def lookup_key(lookup_invocation, location, root_key)
    lookup_invocation.report_found(root_key, data_value(lookup_invocation, location, root_key))
  end

  def data_value(lookup_invocation, location, root_key)
    hash = data_hash(lookup_invocation, location)
    value = hash[root_key]
    if value.nil? && !hash.include?(root_key)
      lookup_invocation.report_not_found(root_key)
      throw :no_such_key
    end
    value = validate_data_value(value) do
      msg = "Value for key '#{root_key}', in hash returned from #{full_name}"
      location.nil? ? msg : "#{msg}, when using location '#{location}',"
    end
    interpolate(value, lookup_invocation, true)
  end

  def data_hash(lookup_invocation, location)
    ctx = function_context(lookup_invocation, location)
    ctx.data_hash ||= parent_data_provider.validate_data_hash(call_data_hash_function(ctx, lookup_invocation, location)) do
      msg = "Value returned from #{full_name}"
      location.nil? ? msg : "#{msg}, when using location '#{location}',"
    end
  end

  def call_data_hash_function(ctx, lookup_invocation, location)
    ctx.function.call(lookup_invocation.scope, options(location), Context.new(ctx, lookup_invocation))
  end
end

# @api private
class V3DataHashFunctionProvider < DataHashFunctionProvider
  TAG = 'v3_data_hash'.freeze

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
          invoke_with_location(lookup_invocation, location, root_key)
        end
      end
    end
  end
end

# TODO: API 5.0, remove this class
# @api private
class V4DataHashFunctionProvider < DataHashFunctionProvider
  TAG = 'v4_data_hash'.freeze

  def name
    "Deprecated API function \"#{function_name}\""
  end

  def full_name
    "deprecated API function '#{function_name}'"
  end

  def call_data_hash_function(ctx, lookup_invocation, location)
    ctx.function.call(lookup_invocation.scope)
  end
end
end
end
