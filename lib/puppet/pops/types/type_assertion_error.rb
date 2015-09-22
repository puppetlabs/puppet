
module Puppet::Pops::Types
  # Raised when an assertion of actual type against an expected type fails.
  #
  class TypeAssertionError < Puppet::Error

    # Returns the expected type
    # @return [PAnyType] expected type
    attr_reader :expected_type

    # Returns the actual type
    # @return [PAnyType] actual type
    attr_reader :actual_type

    # Creates a new instance with a default message, expected, and actual types,
    #
    # @param message [String] The default message
    # @param expected_type [PAnyType] The expected type
    # @param actual_type [PAnyType] The actual type
    #
    def initialize(message, expected_type, actual_type)
      super(message)
      @expected_type = expected_type
      @actual_type = actual_type
    end
  end
end
