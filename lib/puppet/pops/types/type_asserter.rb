# Utility module for type assertion
#
module Puppet::Pops::Types::TypeAsserter
  # Asserts that a type_to_check is assignable to required_type and raises
  # a {Puppet::ParseError} if that's not the case
  #
  # @param subject [String] String to be prepended to the exception message
  # @param expected_type [PAnyType] Expected type
  # @param type_to_check [PAnyType] Type to check against the required type
  # @return The type_to_check argument
  #
  def self.assert_assignable(subject, expected_type, type_to_check)
    check_assignability(Puppet::Pops::Types::TypeCalculator.singleton, subject, expected_type, type_to_check)
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
  def self.assert_instance_of(subject, expected_type, value, nil_ok = false)
    if !(value.nil? && nil_ok)
      tc = Puppet::Pops::Types::TypeCalculator.singleton
      check_assignability(tc, subject, expected_type, tc.infer_set(value), true)
    end
    value
  end

  def self.check_assignability(tc, subject, expected_type, actual_type, inferred = false)
    unless tc.assignable?(expected_type, actual_type)
      # Do not give all the details for inferred types - i.e. format as Integer, instead of Integer[n, n] for exact
      # value, which is just confusing. (OTOH: may need to revisit, or provide a better "type diff" output).
      #
      actual_type = Puppet::Pops::Types::TypeCalculator.generalize!(actual_type) if inferred
      raise Puppet::Pops::Types::TypeAssertionError.new(
        "#{subject} value has wrong type, expected #{tc.string(expected_type)}, actual #{tc.string(actual_type)}", expected_type, actual_type)
    end
  end
  private_class_method :check_assignability
end
