# This class is the backing implementation of the Puppet function 'lookup'.
# See puppet/functions/lookup.rb for documentation.
#
class Puppet::Pops::Lookup
  # Performs a lookup in the configured scopes and optionally merges the default.
  #
  # This is a backing function and all parameters are assumed to have been type checked.
  # See puppet/functions/lookup.rb for full documentation and all parameter combinations.
  #
  # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
  # @param name [String|Array<String>] The name or names to lookup
  # @param type [Puppet::Pops::Types::PAnyType|nil] The expected type of the found value
  # @param default_value [Object] The value to use as default when no value is found
  # @param has_default [Boolean] Set to _true_ if _default_value_ is included (_nil_ is a valid _default_value_)
  # @param override [Hash<String,Object>|nil] A map to use as override. Values found here are returned immediately (no merge)
  # @param default_values_hash [Hash<String,Object>] A map to use as the last resort (but before default)
  # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
  # @return [Object] The found value
  #
  def self.lookup(scope, name, value_type, default_value, has_default, override, default_values_hash, merge)
    value_type = Puppet::Pops::Types::PDataType.new if value_type.nil?
    names = name.is_a?(Array) ? name : [name]

    # find first name that yields a non-nil result and wrap it in a two element array
    # with name and value.
    not_found = Object.new
    result_with_name = names.reduce([nil,not_found]) do |memo, key|
      value = override.include?(key) ? assert_type('override', value_type, override[key]) : not_found
      value = search_and_merge(key, scope, merge, not_found) if value.equal?(not_found)
      break [key, assert_type('found', value_type, value)] unless value.equal?(not_found)
      memo
    end

    # Use the 'default_values_hash' map as a last resort if nothing is found
    if result_with_name[1].equal?(not_found) && !default_values_hash.empty?
      result_with_name = names.reduce(result_with_name) do |memo, key|
        value = default_values_hash.include?(key) ? assert_type('default_values_hash', value_type, default_values_hash[key]) : not_found
        memo = [ key, value ]
        break memo unless value.equal?(not_found)
        memo
      end
    end

    answer = result_with_name[1]
    if answer.equal?(not_found)
      if block_given?
        answer = assert_type('default_block', value_type, yield(name))
      elsif has_default
        answer = assert_type('default_value', value_type, default_value)
      else
        fail_lookup(names)
      end
    end
    answer
  end

  def self.search_and_merge(name, scope, merge, not_found)
    in_global = lambda { lookup_with_databinding(name, scope, merge) }
    in_env = lambda { Puppet::DataProviders.lookup_in_environment(name, scope, merge) }
    in_module = lambda { Puppet::DataProviders.lookup_in_module(name, scope, merge) }

    [in_global, in_env, in_module].reduce(not_found) do |memo, f|
      found = false # can't trust catch return value since nil is valid
      value = catch (:no_such_key) do
        answer = f.call
        found = true
        answer
      end
      next memo unless found
      break value if merge.nil? # value found and no merge
      strategy = Puppet::Pops::MergeStrategy.strategy(merge)
      memo.equal?(not_found) ? strategy.convert_value(value) : strategy.merge(memo, value)
    end
  end
  private_class_method :search_and_merge

  def self.lookup_with_databinding(key, scope, merge)
    begin
      Puppet::DataBinding.indirection.find(key, { :environment => scope.environment.to_s, :variables => scope, :merge => merge })
    rescue Puppet::DataBinding::LookupError => e
      raise Puppet::Error, "Error from DataBinding '#{Puppet[:data_binding_terminus]}' while looking up '#{name}': #{e.message}", e
    end
  end
  private_class_method :lookup_with_databinding

  def self.assert_type(subject, type, value)
    Puppet::Pops::Types::TypeAsserter.assert_instance_of(subject, type, value)
  end
  private_class_method :assert_type

  def self.fail_lookup(names)
    name_part = names.size == 1 ? "the name '#{names[0]}'" : 'any of the names [' + names.map {|n| "'#{n}'"} .join(', ') + ']'
    raise Puppet::Error, "Function lookup() did not find a value for #{name_part}"
  end
  private_class_method :fail_lookup
end
