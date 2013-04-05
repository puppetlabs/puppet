# Provides utility methods
module Puppet::Pops::Utils
  # Can the given o be converted to numeric? (or is numeric already)
  # Accepts a leading '::'
  # Returns a boolean if the value is numeric
  # If testing if value can be converted it is more efficient to call {#to_n} or {#to_n_with_radix} directly
  # and check if value is nil.
  def self.is_numeric?(o)
    case o
    when Numeric, Integer, Fixnum, Float
      !!o
    else
      !!Puppet::Pops::Patterns::NUMERIC.match(relativize_name(o.to_s))
    end
  end

  # To LiteralNumber with radix, or nil if not a number.
  # If the value is already a number it is returned verbatim with a radix of 10.
  # @param o [String, Number] a string containing a number in octal, hex, integer (decimal) or floating point form
  # @return [Array<Number, Integer>, nil] array with converted number and radix, or nil if not possible to convert
  # @api public
  #
  def self.to_n_with_radix o
    begin
      case o
      when String
        match = Puppet::Pops::Patterns::NUMERIC.match(relativize_name(o))
        if !match
          nil
        elsif match[3].to_s.length > 0
          # Use default radix (default is decimal == 10) for floats
          [Float(match[0]), 10]
        else
          # Set radix (default is decimal == 10)
          radix = 10
          if match[1].to_s.length > 0
            radix = 16
          elsif match[2].to_s.length > 0 && match[2][0] == '0'
            radix = 8
          end
          [Integer(match[0], radix), radix]
        end
      when Numeric, Fixnum, Integer, Float
        # Impossible to calculate radix, assume decimal
        [o, 10]
      else
        nil
      end
    rescue ArgumentError
      nil
    end
  end

  # To Numeric (or already numeric)
  # Returns nil if value is not numeric, else an Integer or Float
  # A leading '::' is accepted (and ignored)
  #
  def self.to_n o
    begin
      case o
      when String
        match = Puppet::Pops::Patterns::NUMERIC.match(relativize_name(o))
        if !match
          nil
        elsif match[3].to_s.length > 0
          Float(match[0])
        else
          Integer(match[0])
        end
      when Numeric, Fixnum, Integer, Float
        o
      else
        nil
      end
    rescue ArgumentError
      nil
    end
  end

  # is the name absolute (i.e. starts with ::)
  def self.is_absolute? name
    name.start_with? "::"
  end

  def self.name_to_segments name
    name.split("::")
  end

  def self.relativize_name name
    is_absolute?(name) ? name[2..-1] : name
  end

  # Finds an adapter for o or for one of its containers, or nil, if none of the containers
  # was adapted with the given adapter.
  # This method can only be used with objects that respond to `:eContainer`.
  # with true, and Adaptable#adapters.
  #
  def self.find_adapter(o, adapter)
    return nil unless o
    a = adapter.get(o)
    return a if a
    return find_adapter(o.eContainer, adapter)
  end
end
