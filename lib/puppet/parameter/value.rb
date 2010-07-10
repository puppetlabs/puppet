require 'puppet/parameter/value_collection'

# An individual Value class.
class Puppet::Parameter::Value
  attr_reader :name, :options, :event
  attr_accessor :block, :call, :method, :required_features

  # Add an alias for this value.
  def alias(name)
    @aliases << convert(name)
  end

  # Return all aliases.
  def aliases
    @aliases.dup
  end

  # Store the event that our value generates, if it does so.
  def event=(value)
    @event = convert(value)
  end

  def initialize(name)
    if name.is_a?(Regexp)
      @name = name
    else
      # Convert to a string and then a symbol, so things like true/false
      # still show up as symbols.
      @name = convert(name)
    end

    @aliases = []

    @call = :instead
  end

  # Does a provided value match our value?
  def match?(value)
    if regex?
      return true if name =~ value.to_s
    else
      return(name == convert(value) ? true : @aliases.include?(convert(value)))
    end
  end

  # Is our value a regex?
  def regex?
    @name.is_a?(Regexp)
  end

  private

  # A standard way of converting all of our values, so we're always
  # comparing apples to apples.
  def convert(value)
    if value == ''
      # We can't intern an empty string, yay.
      value
    else
      value.to_s.to_sym
    end
  end
end
