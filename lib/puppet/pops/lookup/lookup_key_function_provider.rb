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
      lookup_invocation.report_found(root_key, value)
    else
      lookup_invocation.with(:location, location) do
        value = lookup_key(root_key, lookup_invocation, location, merge)
        lookup_invocation.report_found(root_key, value)
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
      unless hash.include?(key)
        hash[key] = validate_data_value(ctx.function.call(lookup_invocation.scope, key, options(location), Context.new(ctx, lookup_invocation))) do
          msg = "Value for key '#{key}', returned from #{full_name}"
          location.nil? ? msg : "#{msg}, when using location '#{location}',"
        end
      end
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
end
end
