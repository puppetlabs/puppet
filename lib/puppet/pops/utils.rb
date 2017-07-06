# Provides utility methods
module Puppet::Pops
module Utils
  # Can the given o be converted to numeric? (or is numeric already)
  # Accepts a leading '::'
  # Returns a boolean if the value is numeric
  # If testing if value can be converted it is more efficient to call {#to_n} or {#to_n_with_radix} directly
  # and check if value is nil.
  def self.is_numeric?(o)
    case o
    when Numeric
      true
    else
      !!Patterns::NUMERIC.match(relativize_name(o.to_s))
    end
  end

  # Convert a match from Patterns::NUMERIC to floating point value if
  # possible
  def self.match_to_fp(match)
    if match[5].to_s.length > 0
      # Use default radix (default is decimal == 10) for floats
      # Do not convert a value that is 0 raised to 10^somevalue to float - the value is always 0
      # i.e. 0000.0e1, 0e1, 0.0000e1
      if Integer(match[4]) == 0 && match[5] =~ /\A\.?0*[eE].*\z/
        nil
      else
        fp_value = Float(match[2])
        if fp_value != Float::INFINITY
          match[1] == '-' ? -fp_value : fp_value
        else
          nil
        end
      end
    end
  end

  # To Numeric with radix, or nil if not a number.
  # If the value is already Numeric it is returned verbatim with a radix of 10.
  # @param o [String, Number] a string containing a number in octal, hex, integer (decimal) or floating point form
  #   with optional sign +/-
  # @return [Array<Number, Integer>, nil] array with converted number and radix, or nil if not possible to convert
  # @api public
  #
  def self.to_n_with_radix o
    begin
      case o
      when String
        match = Patterns::NUMERIC.match(relativize_name(o))
        if !match
          nil
        elsif match[5].to_s.length > 0
          fp_value = match_to_fp(match)
          fp_value.nil? ? nil : [fp_value, 10]
        else
          # Set radix (default is decimal == 10)
          radix = 10
          if match[3].to_s.length > 0
            radix = 16
          elsif match[4].to_s.length > 1 && match[4][0,1] == '0'
            radix = 8
          end
          # Ruby 1.8.7 does not have a second argument to Kernel method that creates an
          # integer from a string, it relies on the prefix 0x, 0X, 0 (and unsupported in puppet binary 'b')
          # We have the correct string here, match[2] is safe to parse without passing on radix
          match[1] == '-' ? [-Integer(match[2]), radix] : [Integer(match[2]), radix]
        end
      when Numeric
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
  # Returns nil if value is not numeric, else an Integer or Float. A String may have an optional sign.
  #
  # A leading '::' is accepted (and ignored)
  #
  def self.to_n o
    begin
      case o
      when String
        match = Patterns::NUMERIC.match(relativize_name(o))
        if !match
          nil
        elsif match[5].to_s.length > 0
          match_to_fp(match)
        else
          match[1] == '-' ? -Integer(match[2]) : Integer(match[2])
        end
      when Numeric
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

  # Finds an existing adapter for o or for one of its containers, or nil, if none of the containers
  # was adapted with the given adapter.
  # This method can only be used with objects that respond to `:eContainer`.
  # with true.
  #
  # @see #find_closest_positioned
  #
  def self.find_adapter(o, adapter)
    return nil if o.nil? || (o.is_a?(Array) && o.empty?)
    a = adapter.get(o)
    return a if a
    return find_adapter(o.eContainer, adapter)
  end

  # Finds the closest positioned Model::Positioned object, or object decorated with
  # a SourcePosAdapter, and returns
  # a SourcePosAdapter for the first found, or nil if not found.
  #
  def self.find_closest_positioned(o)
    return nil if o.nil? || o.is_a?(Model::Program) || (o.is_a?(Array) && o.empty?)
    return find_adapter(o, Adapters::SourcePosAdapter) unless o.is_a?(Model::Positioned)
    o.offset.nil? ? find_closest_positioned(o.eContainer) : Adapters::SourcePosAdapter.adapt(o)
  end
end
end
