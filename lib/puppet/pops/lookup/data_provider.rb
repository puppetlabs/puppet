module Puppet::Pops
module Lookup
# @api private
module DataProvider
  def self.key_type
    ensure_types_initialized
    @key_type
  end

  def self.value_type
    ensure_types_initialized
    @value_type
  end

  def self.ensure_types_initialized
    if @key_type.nil?
      (@key_type, @value_type) = Pcore::register_aliases(
        # The Pcore type for all keys and subkeys in a data hash.
        'Puppet::LookupKey' => 'Variant[String,Boolean,Numeric]',

        # The Pcore type for all values and sub-values in a data hash. The
        # type is self-recursive to enforce the same constraint on values contained
        # in arrays and hashes
        'Puppet::LookupValue' => <<-PUPPET
          Variant[
            Scalar,
            Undef,
            Sensitive,
            Type,
            Hash[Puppet::LookupKey, Puppet::LookupValue],
            Array[Puppet::LookupValue]
          ]
        PUPPET
      )
    end
  end

  # Performs a lookup with an endless recursion check.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String=>Object},nil] Merge strategy or hash with strategy and options
  #
  def key_lookup(key, lookup_invocation, merge)
    lookup_invocation.check(key.to_s) { unchecked_key_lookup(key, lookup_invocation, merge) }
  end

  def lookup(key, lookup_invocation, merge)
    lookup_invocation.check(key.to_s) { unchecked_key_lookup(key, lookup_invocation, merge) }
  end

  # Performs a lookup with the assumption that a recursive check has been made.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String => Object},nil] Merge strategy, merge strategy name, strategy and options hash, or nil (implies "first found")
  # @return [Object] the found object
  # @throw :no_such_key when the object is not found
  def unchecked_key_lookup(key, lookup_invocation, merge)
    raise NotImplementedError, "Subclass of #{DataProvider.name} must implement 'unchecked_lookup' method"
  end

  # @return [String,nil] the name of the module that this provider belongs to nor `nil` if it doesn't belong to a module
  def module_name
    nil
  end

  # @return [String] the name of the this data provider
  def name
    raise NotImplementedError, "Subclass of #{DataProvider.name} must implement 'name' method"
  end

  # Asserts that _data_hash_ is a valid hash.
  #
  # @param data_provider [DataProvider] The data provider that produced the hash
  # @param data_hash [Hash{String=>Object}] The data hash
  # @return [Hash{String=>Object}] The data hash
  def validate_data_hash(data_provider, data_hash)
    Types::TypeAsserter.assert_instance_of(nil, Types::PHashType::DEFAULT, data_hash) { "Value returned from #{data_provider.name}" }
    data_hash.each_pair { |k, v| validate_data_entry(data_provider, k, v) }
    data_hash
  end

  def validate_data_value(data_provider, value, where = '')
    Types::TypeAsserter.assert_instance_of(nil, DataProvider.value_type, value) { "Value #{where}returned from #{data_provider.name}" }
    case value
    when Hash
      value.each_pair { |k, v| validate_data_entry(data_provider, k, v) }
    when Array
      value.each {|v| validate_data_value(data_provider, v, 'in array ') }
    end
    value
  end

  def validate_data_entry(data_provider, key, value)
    Types::TypeAsserter.assert_instance_of(nil, DataProvider.key_type, key) { "Key in hash returned from #{data_provider.name}" }
    validate_data_value(data_provider, value, 'in hash ')
    nil
  end
end
end
end
