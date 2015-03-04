require 'puppet/parameter/value_collection'

# Describes an acceptable value for a parameter or property.
# An acceptable value is either specified as a literal value or a regular expression.
# @note this class should be used via the api methods in {Puppet::Parameter} and {Puppet::Property}
# @api private
#
class Puppet::Parameter::Value
  attr_reader :name, :options, :event
  attr_accessor :block, :method, :required_features, :invalidate_refreshes

  # Adds an alias for this value.
  # Makes the given _name_ be an alias for this acceptable value.
  # @param name [Symbol] the additonal alias this value should be known as
  # @api private
  #
  def alias(name)
    @aliases << convert(name)
  end

  # @return [Array<Symbol>] Returns all aliases (or an empty array).
  # @api private
  #
  def aliases
    @aliases.dup
  end

  # Stores the event that our value generates, if it does so.
  # @api private
  #
  def event=(value)
    @event = convert(value)
  end

  # Initializes the instance with a literal accepted value, or a regular expression.
  # If anything else is passed, it is turned into a String, and then made into a Symbol.
  # @param name [Symbol, Regexp, Object] the value to accept, Symbol, a regular expression, or object to convert.
  # @api private
  #
  def initialize(name)
    if name.is_a?(Regexp)
      @name = name
    else
      # Convert to a string and then a symbol, so things like true/false
      # still show up as symbols.
      @name = convert(name)
    end

    @aliases = []
  end

  # Checks if the given value matches the acceptance rules (literal value, regular expression, or one
  # of the aliases.
  # @api private
  #
  def match?(value)
    if regex?
      return true if name =~ value.to_s
    else
      return(name == convert(value) ? true : @aliases.include?(convert(value)))
    end
  end

  # @return [Boolean] whether the accepted value is a regular expression or not.
  # @api private
  #
  def regex?
    @name.is_a?(Regexp)
  end

  private

  # A standard way of converting all of our values, so we're always
  # comparing apples to apples.
  # @api private
  #
  def convert(value)
    case value
    when Symbol, ''             # can't intern an empty string
      value
    when String
      value.intern
    when true
      :true
    when false
      :false
    else
      value.to_s.intern
    end
  end
end
