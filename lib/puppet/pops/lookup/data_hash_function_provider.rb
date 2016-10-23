require_relative 'function_provider'
require_relative 'interpolation'

module Puppet::Pops
module Lookup
# @api private
class DataHashFunctionProvider < FunctionProvider
  include SubLookup
  include Interpolation

  TAG = 'data_hash'.freeze

  OPTION_KEY_VERBATIM = 'verbatim'.freeze
  OPTION_KEY_PRUNE = 'prune'.freeze

  def initialize(name, parent_data_provider, function_name, options, locations)
    super
    @verbatim = !!options[OPTION_KEY_VERBATIM]
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
          lookup_key(lookup_invocation, location.location, root_key)
        else
          lookup_invocation.report_location_not_found
          throw :no_such_key
        end
      end
    end
  end

  def lookup_key(lookup_invocation, location, root_key)
    value = if @verbatim
      data_value(lookup_invocation, location, root_key)
    else
      if @resolved.nil?
        @resolved = { root_key => data_value(lookup_invocation, location, root_key) }
      else
        @resolved[root_key] = data_value(lookup_invocation, location, root_key) unless @resolved.include?(root_key)
      end
      @resolved[root_key]
    end
    lookup_invocation.report_found(root_key, value)
  end

  def data_value(lookup_invocation, location, root_key)
    hash = data_hash(lookup_invocation, location)
    value = hash[root_key]
    if value.nil? && !hash.include?(root_key)
      lookup_invocation.report_not_found(root_key)
      throw :no_such_key
    end
    @verbatim ? value : interpolate(value, lookup_invocation, true)
  end

  def data_hash(lookup_invocation, location)
    ctx = function_context(lookup_invocation, location)
    ctx.data_hash ||= parent_data_provider.validate_data_hash(self, call_data_hash_function(ctx, lookup_invocation, location))
  end

  def call_data_hash_function(ctx, lookup_invocation, location)
    ctx.function.call(lookup_invocation.scope, options(location), Context.new(ctx, lookup_invocation))
  end
end

class LegacyDataHashFunctionProvider < DataHashFunctionProvider
  TAG = 'legacy_data_hash'.freeze

  def name
    "Legacy function \"#{function_name}\""
  end

  def call_data_hash_function(ctx, lookup_invocation, location)
    ctx.function.call(lookup_invocation.scope)
  end
end
end
end
