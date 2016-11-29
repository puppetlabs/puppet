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
    segments = key.to_a
    lookup_invocation.with(:data_provider, self) do
      MergeStrategy.strategy(merge).lookup(locations, lookup_invocation) do |location|
        if location.nil?
          value = data_dig(key, segments, lookup_invocation, nil)
          lookup_invocation.report_found(key, validate_data_value(self, value))
          key.undig(value)
        else
          lookup_invocation.with(:location, location) do
            if location.exist?
              value = data_dig(key, segments, lookup_invocation, location.location)
              lookup_invocation.report_found(key, validate_data_value(self, value))
              key.undig(value)
            else
              lookup_invocation.report_path_not_found
              throw :no_such_key
            end
          end
        end
      end
    end
  end

  private

  def data_dig(key, segments, lookup_invocation, location)
    ctx = function_context(lookup_invocation, location)
    ctx.data_hash ||= {}
    catch(:no_such_key) do
      hash = ctx.data_hash
      hash[key] = ctx.function.call(lookup_invocation.scope, segments, options(location), Context.new(ctx, lookup_invocation)) unless hash.include?(key)
      return hash[key]
    end
    lookup_invocation.report_not_found(key)
    throw :no_such_key
  end
end
end
end
