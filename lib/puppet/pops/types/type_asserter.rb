# Utility module for type assertion
#
module Puppet::Pops::Types
module TypeAsserter
  # Asserts that a type_to_check is assignable to required_type and raises
  # a {Puppet::ParseError} if that's not the case
  #
  # @param subject [String] String to be prepended to the exception message
  # @param expected_type [PAnyType] Expected type
  # @param type_to_check [PAnyType] Type to check against the required type
  # @return The type_to_check argument
  #
  # @api public
  def self.assert_assignable(subject, expected_type, type_to_check)
    report_type_mismatch(subject, expected_type, type_to_check) unless expected_type.assignable?(type_to_check)
    type_to_check
  end

  # Asserts that a value is an instance of a given type and raises
  # a {Puppet::ParseError} if that's not the case
  #
  # @param subject [String] String to be prepended to the exception message
  # @param expected_type [PAnyType] Expected type for the value
  # @param value [Object] Value to check
  # @param nil_ok [Boolean] Can be true to allow nil value. Optional and defaults to false
  # @return The value argument
  #
  # @api public
  def self.assert_instance_of(subject, expected_type, value, nil_ok = false)
    unless value.nil? && nil_ok
      report_type_mismatch(subject, expected_type, TypeCalculator.singleton.infer_set(value).generalize) unless expected_type.instance?(value)
    end
    value
  end

  # Validates that all entries in the give_hash exists in the given param_struct, that their type conforms
  # with the corresponding param_struct element and that all required values are provided.
  #
  # @param subject [String] String to be prepended to the exception message
  # @param params_struct [PStructType] Struct to use for validation
  # @param given_hash [Hash<String,Object>] The parameters to validate
  #
  # @api private
  # @deprecated Will be removed when improving type mismatch errors handling
  def self.validate_parameters(subject, params_struct, given_hash)
    params_hash = params_struct.hashed_elements
    given_hash.each_key { |name| raise Puppet::ParseError.new("Invalid parameter: '#{name}' on #{subject}") unless params_hash.include?(name) }

    params_struct.elements.each do |elem|
      name = elem.name
      value = given_hash[name]
      if given_hash.include?(name)
        assert_instance_of("#{subject} '#{name}'", elem.value_type, value)
      else
        raise Puppet::ParseError.new("Must pass '#{name}' to #{subject}") unless elem.key_type.assignable?(PUndefType::DEFAULT)
      end
    end
  end

  def self.report_type_mismatch(subject, expected_type, actual_type)
      # Do not give all the details for inferred types - i.e. format as Integer, instead of Integer[n, n] for exact
      # value, which is just confusing. (OTOH: may need to revisit, or provide a better "type diff" output).
      #
      raise TypeAssertionError.new(
          "#{subject} value has wrong type, expected #{expected_type}, actual #{actual_type}", expected_type, actual_type)
  end
  private_class_method :report_type_mismatch
end
end

