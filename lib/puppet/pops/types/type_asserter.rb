module Puppet::Pops::Types
  # Utility class for type assertion
  #
  class TypeAsserter
    # Asserts that a type_to_check is assignable to required_type and raises
    # a {Puppet::ParseError} if that's not the case
    #
    # @param subject [String] String to be prepended to the exception message
    # @param required_type [PAnyType] Required type
    # @param type_to_check [PAnyType] Type to check against the required type
    # @return The type_to_check argument
    #
    def self.assert_assignable(subject, required_type, type_to_check)
      check_assignability(TypeCalculator.singleton, subject, required_type, type_to_check)
      type_to_check
    end

    # Asserts that a value is an instance of a given type and raises
    # a {Puppet::ParseError} if that's not the case
    #
    # @param subject [String] String to be prepended to the exception message
    # @param required_type [PAnyType] Required type for the value
    # @param value [Object] Value to check
    # @param nil_ok [Boolean] Can be true to allow nil value. Optional and defaults to false
    # @return The value argument
    #
    def self.assert_instance_of(subject, required_type, value, nil_ok = false)
      if !(value.nil? && nil_ok)
        tc = TypeCalculator.singleton
        check_assignability(tc, subject, required_type, tc.infer(value))
      end
      value
    end

    def self.check_assignability(tc, subject, wanted, got)
      raise Puppet::ParseError, "#{subject} value has wrong type, expected #{tc.string(wanted)}, got #{tc.string(got)}" unless tc.assignable?(wanted, got)
    end
    private_class_method :check_assignability
  end
end
