# This class is the backing implementation of the Puppet function 'lookup'.
# See puppet/functions/lookup.rb for documentation.
#
module Puppet::Pops
module Lookup
  LOOKUP_OPTIONS = 'lookup_options'.freeze
  GLOBAL = '__global__'.freeze

  # Performs a lookup in the configured scopes and optionally merges the default.
  #
  # This is a backing function and all parameters are assumed to have been type checked.
  # See puppet/functions/lookup.rb for full documentation and all parameter combinations.
  #
  # @param name [String|Array<String>] The name or names to lookup
  # @param type [Types::PAnyType|nil] The expected type of the found value
  # @param default_value [Object] The value to use as default when no value is found
  # @param has_default [Boolean] Set to _true_ if _default_value_ is included (_nil_ is a valid _default_value_)
  # @param merge [MergeStrategy,String,Hash<String,Object>,nil] Merge strategy or hash with strategy and options
  # @param lookup_invocation [Invocation] Invocation data containing scope, overrides, and defaults
  # @return [Object] The found value
  #
  def self.lookup(name, value_type, default_value, has_default, merge, lookup_invocation)
    value_type = Types::PDataType::DEFAULT if value_type.nil?
    names = name.is_a?(Array) ? name : [name]

    # find first name that yields a non-nil result and wrap it in a two element array
    # with name and value.
    not_found = MergeStrategy::NOT_FOUND
    override_values = lookup_invocation.override_values
    result_with_name = names.reduce([nil, not_found]) do |memo, key|
      value = override_values.include?(key) ? assert_type(["Value found for key '%s' in override hash", key], value_type, override_values[key]) : not_found
      catch(:no_such_key) { value = search_and_merge(key, lookup_invocation, merge) } if value.equal?(not_found)
      break [key, assert_type('Found value', value_type, value)] unless value.equal?(not_found)
      memo
    end

    # Use the 'default_values' hash as a last resort if nothing is found
    if result_with_name[1].equal?(not_found)
      default_values = lookup_invocation.default_values
      unless default_values.empty?
        result_with_name = names.reduce(result_with_name) do |memo, key|
          value = default_values.include?(key) ? assert_type(["Value found for key '%s' in default values hash", key], value_type, default_values[key]) : not_found
          memo = [key, value]
          break memo unless value.equal?(not_found)
          memo
        end
      end
    end

    answer = result_with_name[1]
    if answer.equal?(not_found)
      if block_given?
        answer = assert_type('Value returned from default block', value_type, yield(name))
      elsif has_default
        answer = assert_type('Default value', value_type, default_value)
      else
        fail_lookup(names)
      end
    end
    answer
  end

  # @api private
  def self.search_and_merge(name, lookup_invocation, merge)
    return Puppet::DataProviders.lookup_adapter(lookup_invocation).lookup(name, lookup_invocation, merge)
  end

  def self.assert_type(subject, type, value)
    Types::TypeAsserter.assert_instance_of(subject, type, value)
  end
  private_class_method :assert_type

  def self.fail_lookup(names)
    name_part = names.size == 1 ? "the name '#{names[0]}'" : 'any of the names [' + names.map { |n| "'#{n}'" }.join(', ') + ']'
    raise Puppet::DataBinding::LookupError, "Function lookup() did not find a value for #{name_part}"
  end
  private_class_method :fail_lookup
end
end
