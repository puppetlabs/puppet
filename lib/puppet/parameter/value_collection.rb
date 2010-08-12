require 'puppet/parameter/value'

# A collection of values and regexes, used for specifying
# what values are allowed in a given parameter.
class Puppet::Parameter::ValueCollection

  def aliasvalue(name, other)
    other = other.to_sym
    unless value = match?(other)
      raise Puppet::DevError, "Cannot alias nonexistent value #{other}"
    end

    value.alias(name)
  end

  # Return a doc string for all of the values in this parameter/property.
  def doc
    unless defined?(@doc)
      @doc = ""
      unless values.empty?
        @doc += "  Valid values are "
        @doc += @strings.collect do |value|
          if aliases = value.aliases and ! aliases.empty?
            "`#{value.name}` (also called `#{aliases.join(", ")}`)"
          else
            "`#{value.name}`"
          end
        end.join(", ") + "."
      end

      @doc += "  Values can match `" + regexes.join("`, `") + "`." unless regexes.empty?
    end

    @doc
  end

  # Does this collection contain any value definitions?
  def empty?
    @values.empty?
  end

  def initialize
    # We often look values up by name, so a hash makes more sense.
    @values = {}

    # However, we want to retain the ability to match values in order,
    # but we always prefer directly equality (i.e., strings) over regex matches.
    @regexes = []
    @strings = []
  end

  # Can we match a given value?
  def match?(test_value)
    # First look for normal values
    if value = @strings.find { |v| v.match?(test_value) }
      return value
    end

    # Then look for a regex match
    @regexes.find { |v| v.match?(test_value) }
  end

  # If the specified value is allowed, then munge appropriately.
  def munge(value)
    return value if empty?

    if instance = match?(value)
      if instance.regex?
        return value
      else
        return instance.name
      end
    else
      return value
    end
  end

  # Define a new valid value for a property.  You must provide the value itself,
  # usually as a symbol, or a regex to match the value.
  #
  # The first argument to the method is either the value itself or a regex.
  # The second argument is an option hash; valid options are:
  # * <tt>:event</tt>: The event that should be returned when this value is set.
  # * <tt>:call</tt>: When to call any associated block.  The default value
  #   is ``instead``, which means to call the value instead of calling the
  #   provider.  You can also specify ``before`` or ``after``, which will
  #   call both the block and the provider, according to the order you specify
  #   (the ``first`` refers to when the block is called, not the provider).
  def newvalue(name, options = {}, &block)
    value = Puppet::Parameter::Value.new(name)
    @values[value.name] = value
    if value.regex?
      @regexes << value
    else
      @strings << value
    end

    options.each { |opt, arg| value.send(opt.to_s + "=", arg) }
    if block_given?
      value.block = block
    else
      value.call = options[:call] || :none
    end

    value.method ||= "set_#{value.name}" if block_given? and ! value.regex?

    value
  end

  # Define one or more new values for our parameter.
  def newvalues(*names)
    names.each { |name| newvalue(name) }
  end

  def regexes
    @regexes.collect { |r| r.name.inspect }
  end

  # Verify that the passed value is valid.
  def validate(value)
    return if empty?

    unless @values.detect { |name, v| v.match?(value) }
      str = "Invalid value #{value.inspect}. "

      str += "Valid values are #{values.join(", ")}. " unless values.empty?

      str += "Valid values match #{regexes.join(", ")}." unless regexes.empty?

      raise ArgumentError, str
    end
  end

  # Return a single value instance.
  def value(name)
    @values[name]
  end

  # Return the list of valid values.
  def values
    @strings.collect { |s| s.name }
  end
end
