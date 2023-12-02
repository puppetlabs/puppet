# frozen_string_literal: true

module Puppet::Pops::Types
  # Raised when a conversion of a value to another type failed.
  #
  class TypeConversionError < Puppet::Error; end
end
