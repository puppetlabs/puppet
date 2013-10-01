# Various methods used to coerce values into a canonical form.
#
# @api private
module Puppet::Coercion
  # Try to coerce various input values into boolean true/false
  #
  # Only a very limited subset of values are allowed. This method does not try
  # to provide a generic "truthiness" system.
  #
  # @param value [Boolean, Symbol, String]
  # @return [Boolean]
  # @raise
  # @api private
  def self.boolean(value)
    # downcase strings
    if value.respond_to? :downcase
      value = value.downcase
    end

    case value
    when true, :true, 'true', :yes, 'yes'
      true
    when false, :false, 'false', :no, 'no'
      false
    else
      fail('expected a boolean value')
    end
  end

  # Return the list of acceptable boolean values.
  #
  # This is limited to lower-case, even though boolean() is case-insensitive.
  #
  # @return [Array]
  # @raise
  # @api private
  def self.boolean_values
    ['true', 'false', 'yes', 'no']
  end
end
