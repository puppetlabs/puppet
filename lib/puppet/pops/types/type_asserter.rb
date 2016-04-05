# Utility module for type assertion
#
module Puppet::Pops::Types
module TypeAsserter
  # Asserts that a type_to_check is assignable to required_type and raises
  # a {Puppet::ParseError} if that's not the case
  #
  # @param subject [String,Array] String to be prepended to the exception message or Array where the first element is
  #   a format string and the rest are arguments to that format string
  # @param expected_type [PAnyType] Expected type
  # @param type_to_check [PAnyType] Type to check against the required type
  # @return The type_to_check argument
  #
  # @api public
  def self.assert_assignable(subject, expected_type, type_to_check, &block)
    report_type_mismatch(subject, expected_type, type_to_check) unless expected_type.assignable?(type_to_check)
    type_to_check
  end

  # Asserts that a value is an instance of a given type and raises
  # a {Puppet::ParseError} if that's not the case
  #
  # @param subject [String,Array] String to be prepended to the exception message or Array where the first element is
  #                               a format string and the rest are arguments to that format string
  # @param expected_type [PAnyType] Expected type for the value
  # @param value [Object] Value to check
  # @param nil_ok [Boolean] Can be true to allow nil value. Optional and defaults to false
  # @return The value argument
  #
  # @api public
  def self.assert_instance_of(subject, expected_type, value, nil_ok = false, &block)
    unless value.nil? && nil_ok
      report_type_mismatch(subject, expected_type, TypeCalculator.singleton.infer_set(value), &block) unless expected_type.instance?(value)
    end
    value
  end

  def self.report_type_mismatch(subject, expected_type, actual_type)
    subject = yield(subject) if block_given?
    subject = subject[0] % subject[1..-1] if subject.is_a?(Array)
    raise TypeAssertionError.new(
      TypeMismatchDescriber.singleton.describe_mismatch("#{subject} had wrong type,", expected_type, actual_type), expected_type, actual_type)
  end
  private_class_method :report_type_mismatch
end
end

