
module Puppet::Pops::Types
  # Raised when a conversion of a value to another type failed.
  #
  class TypeConversionError < Puppet::Error

    # Creates a new instance with a given message
    #
    # @param message [String] The error message describing what failed
    #
    def initialize(message)
      super(message)
    end
  end
end
