# The virtual base class for properties, which are the self-contained building
# blocks for actually doing work on the system.

require 'puppet'
require 'puppet/parameter'

# A Property is a specialized Resource Type Parameter that has both an 'is' (current) state, and
# a 'should' (wanted state).
# A Property (also in contrast to a parameter) is intended to describe a managed attribute of
# some system entity, such as the name or mode of a file.
#
# All properties in the puppet system are derived from this class.
#
# The intention is that new parameters are created by using the DSL method {Puppet::Type.newproperty}.
# 
# @api public
# 
class Puppet::Property < Puppet::Parameter
  require 'puppet/property/ensure'

  # Because 'should' uses an array, we have a special method for handling
  # it.  We also want to keep copies of the original values, so that
  # they can be retrieved and compared later when merging.
  # @todo Figure out what the cryptic comment really means.
  attr_reader :shouldorig

  # The noop mode for this property.
  # By setting a property's noop mode to `true`, any management of this property is inhibited. Calculation
  # and reporting still takes place, but if a change of the underlying managed entity's state 
  # should take place it will not be carried out. This noop
  # setting overrides the overall `Puppet[:noop]` mode as well as the noop mode in the _associated resource_ 
  #
  attr_writer :noop

  class << self
    # @todo Figure out what this is used for.
    attr_accessor :unmanaged
    
    # @return [Symbol] The name of the property as given when the property was created.
    # 
    attr_reader :name

    # @!attribute [rw] array_matching
    # @comment note that $#46; is a period - char code require to not terminate sentence.
    # The `is` vs&#46; `should` array matching mode; `:first`, or `:all`.
    # 
    # @comment there are two blank chars after the symbols to cause a break - do not remove these.
    # * `:first`  
    #   This is primarily used for single value properties. When matched against an array of values
    #   a match is true if the `is` value matches any of the values in the `should` array. When the `is` value
    #   is also an array, the matching is performed against the entire array as the `is` value.
    # * `:all`  
    #   : This is primarily used for multi-valued properties. When matched against an array of
    #     `should` values, the size of `is` and `should` must be the same, and all values in `is` must match
    #     a value in `should`.
    #
    # @note The semantics of these modes are implemented by the method {#insync?}, which in the default
    #   implementation in this class has a backwards compatible behavior that imposes additional constraints
    #   on what constitutes a positive match. 
    # @return [:Symbol] (:first) the mode in which matching is performed
    # @see #insync?
    #
    def array_matching
      @array_matching ||= :first
    end

    # @comment This is documented as an attribute - see the {array_matching} method.
    #
    def array_matching=(value)
      value = value.intern if value.is_a?(String)
      raise ArgumentError, "Supported values for Property#array_matching are 'first' and 'all'" unless [:first, :all].include?(value)
      @array_matching = value
    end
  end

  # Looks up a value's name among valid values, to enable option lookup with result as a key.
  # @param name [Object] the parameter value to match against valid values (names). 
  # @return {Symbol, Regexp} a value matching predicate  
  def self.value_name(name)
    if value = value_collection.match?(name)
      value.name
    end
  end

  # Retrieves an option set when a valid value was defined.
  # @param name [Symbol, Regexp] the valid value predicate as returned by {value_name}
  # @param option [Symbol] the name of the wanted option
  # @return [Object] value of the option
  # @raise [NoMethodError] if the option is not supported
  # @todo Guessing on result of passing a non supported option (it performs send(option)).
  #
  def self.value_option(name, option)
    if value = value_collection.value(name)
      value.send(option)
    end
  end

  # Defines a new valid value for this property.
  # A valid value is specified as a literal (typically a Symbol), but can also be
  # specified with a regexp.
  #
  # @param name [Symbol, Regexp] a valid literal value, or a regexp that matches a value
  # @param options [Hash] a hash with options
  # @option options [Symbol] :event The event that should be emitted when this value is set.
  # @todo Option :event original comment says "event should be returned...", is "returned" the correct word
  #   to use?
  # @option options [Symbol] :call When to call any associated block. The default value is `:instead` which
  #   means that the block should be called instead of the provider. A value of `:before` or `:after` will call
  #   both the block and the provider (it is the block that is called before or after in accordance with
  #   the option.
  # @option options [Object] any Any other option is treated as a call to a setter having the given
  #   option name (e.g. `:required_features` calls `required_features=` with the option's value as an
  #   argument).
  # @todo The original documentation states that the option `:method` will set the name of the generated
  #   setter method, but this is not implemented. Is the documentatin or the implementation in error?
  #   (The implementation is in Puppet::Parameter::ValueCollection#new_value).
  #
  # @dsl type
  # @api public
  def self.newvalue(name, options = {}, &block)
    value = value_collection.newvalue(name, options, &block)

    define_method(value.method, &value.block) if value.method and value.block
    value
  end

  # Calls the provider setter method for this property with the given value as argument.
  # @return [Object] what the provider returns when calling a setter for this property's name
  # @raise [? fail] when the provider can not handle this property.
  # @todo What is the intent of this method?
  #
  def call_provider(value)
      method = self.class.name.to_s + "="
      unless provider.respond_to? method
        self.fail "The #{provider.class.name} provider can not handle attribute #{self.class.name}"
      end
      provider.send(method, value)
  end

  # Calls the dynamically-created method associated with our "value", if
  # there is one.
  def call_valuemethod(name, value)
    if method = self.class.value_option(name, :method) and self.respond_to?(method)
      begin
        event = self.send(method)
      rescue Puppet::Error
        raise
      rescue => detail
        error = Puppet::ResourceError.new("Could not set '#{value}' on #{self.class.name}: #{detail}", @resource.line, @resource.file, detail)
        error.set_backtrace detail.backtrace
        Puppet.log_exception(detail, error.message)
        raise error
      end
    elsif block = self.class.value_option(name, :block)
      # FIXME It'd be better here to define a method, so that
      # the blocks could return values.
      self.instance_eval(&block)
    else
      devfail "Could not find method for value '#{name}'"
    end
  end

  # Formats a message for a property change from current value to new value.
  # @return [String] a message describing the property change.
  # @note If called with equal values, this is reported as a change.
  # @raise [Puppet::DevError] if there were issues formatting the message
  #
  def change_to_s(current_value, newvalue)
    begin
      if current_value == :absent
        return "defined '#{name}' as #{self.class.format_value_for_display should_to_s(newvalue)}"
      elsif newvalue == :absent or newvalue == [:absent]
        return "undefined '#{name}' from #{self.class.format_value_for_display is_to_s(current_value)}"
      else
        return "#{name} changed #{self.class.format_value_for_display is_to_s(current_value)} to #{self.class.format_value_for_display should_to_s(newvalue)}"
      end
    rescue Puppet::Error, Puppet::DevError
      raise
    rescue => detail
      message = "Could not convert change '#{name}' to string: #{detail}"
      Puppet.log_exception(detail, message)
      raise Puppet::DevError, message
    end
  end

  # Produces the name of the event to use to describe the change.
  # The produced event name is either the event name configured for this property, or a generic
  # event based on the name of the property with suffix `_changed`, or if the property is
  # `:ensure`, the name of the resource type and one of the suffixes `_created`, `_removed`, or `_changed`.
  # @return [String] the name of the event that describes the change
  #
  def event_name
    value = self.should

    event_name = self.class.value_option(value, :event) and return event_name

    name == :ensure or return (name.to_s + "_changed").to_sym

    return (resource.type.to_s + case value
    when :present; "_created"
    when :absent; "_removed"
    else
      "_changed"
    end).to_sym
  end

  # Returns a modified form of the resource event.
  # @todo What is the intent of this method?
  def event
    resource.event :name => event_name, :desired_value => should, :property => self, :source_description => path
  end

  # @todo What is this?
  #
  attr_reader :shadow

  # Handles initialization of special case when a property is ??? what
  # @todo There is some special initialization when a property is not a metaparameter but
  #   Puppet::Type.metaparamclass(for this class's name) is not nil - if that is the case a 
  #   setup_shadow is performed for that class.
  # 
  # @param hash [Hash] ({}) options passed to the super initializer {Puppet::Parameter.initialize}
  # @note New properties of a type should be created via the DSL method `newproperty`.
  #
  # @api private
  def initialize(hash = {})
    super

    if ! self.metaparam? and klass = Puppet::Type.metaparamclass(self.class.name)
      setup_shadow(klass)
    end
  end

  # Determines whether the property is in-sync or not in a way that is protected against missing value.
  # @note If the wanted value (_should_) is not defined or is set to a non-true value then this is
  #   a state that can not be fixed and the property is reported to be in sync.
  # @return [Boolean] the protected result of `true` or the result of calling {#insync?}.
  #
  # @api private
  # @note Do not override this method.
  #
  def safe_insync?(is)
    # If there is no @should value, consider the property to be in sync.
    return true unless @should

    # Otherwise delegate to the (possibly derived) insync? method.
    insync?(is)
  end

  # Protects against override of the {#safe_insync?} method.
  # @raise [?] if the added method is `:safe_insync?`
  # @api private
  #
  def self.method_added(sym)
    raise "Puppet::Property#safe_insync? shouldn't be overridden; please override insync? instead" if sym == :safe_insync?
  end

  # Checks if the current (_is_) value is in sync with the wanted (_should_) value.
  # The check if the two values are in sync is controlled by the result of {#match_all?} which
  # specifies a match of `:first` or `:all`). The matching of the _is_ value against the entire _should_ value
  # or each of the _should_ values (as controlled by {#match_all?} is performed by #{property_matches?}.
  #
  # A derived property typically only needs to override the #{property_matches?} method, but may also
  # override this method if there is a need to have more control over the array matching logic.
  #
  # @note The array matching logic in this method contains backwards compatible logic that performs the
  #   comparison in `:all` mode by checking equality and equality of _is_ against _should_ converted to array of String,
  #   and that the lengths are equal, and in `:first` mode by checking if one of the _should_ values
  #   is included in the _is_ values. This means that the _is_ value needs to be carefully arranged to
  #   match the _should_.
  # @todo The implementation should really do return is.zip(@should).all? {|a, b| property_matches?(a, b) }
  #   instead of using equality check, and then check against an array with converted strings.
  # 
  def insync?(is)
    self.devfail "#{self.class.name}'s should is not array" unless @should.is_a?(Array)

    # an empty array is analogous to no should values
    return true if @should.empty?

    # Look for a matching value, either for all the @should values, or any of
    # them, depending on the configuration of this property.
    if match_all? then
      # Emulate Array#== using our own comparison function.
      # A non-array was not equal to an array, which @should always is.
      return false unless is.is_a? Array

      # If they were different lengths, they are not equal.
      return false unless is.length == @should.length

      # Finally, are all the elements equal?  In order to preserve the
      # behaviour of previous 2.7.x releases, we need to impose some fun rules
      # on "equality" here.
      #
      # Specifically, we need to implement *this* comparison: the two arrays
      # are identical if the is values are == the should values, or if the is
      # values are == the should values, stringified.
      #
      # This does mean that property equality is not commutative, and will not
      # work unless the `is` value is carefully arranged to match the should.
      return (is == @should or is == @should.map(&:to_s))

      # When we stop being idiots about this, and actually have meaningful
      # semantics, this version is the thing we actually want to do.
      #
      # return is.zip(@should).all? {|a, b| property_matches?(a, b) }
    else
      return @should.any? {|want| property_matches?(is, want) }
    end
  end

  # Checks if the given current and desired values are equal.
  # This default implementation performs this check in a backwards compatible way where
  # the equality of the two values is checked, and then the equality of current with desired 
  # converted to a string.
  # 
  # A derived implementation may override this method to perform a property specific equality check.
  # 
  # The intent of this method is to provide an equality check suitable for checking if the property
  # value is in sync or not. It is typically called from {#insync?}.
  #
  def property_matches?(current, desired)
    # This preserves the older Puppet behaviour of doing raw and string
    # equality comparisons for all equality.  I am not clear this is globally
    # desirable, but at least it is not a breaking change. --daniel 2011-11-11
    current == desired or current == desired.to_s
  end

  # Produces a pretty printing string for the given value.
  # This default implementation simply returns the given argument. A derived implementation
  # may perform property specific pretty printing when the _is_ and _should_ values are not
  # already in suitable form.
  #
  def is_to_s(currentvalue)
    currentvalue
  end

  # Emits a log message at the log level specified for the associated resource.
  # The log entry is associated with this property.
  # @param msg [String] the message to log
  # @return [void]
  #
  def log(msg)
    Puppet::Util::Log.create(
      :level   => resource[:loglevel],
      :message => msg,
      :source  => self
    )
  end

  # @return [Boolean] whether the {array_matching} mode is set to `:all` or not
  def match_all?
    self.class.array_matching == :all
  end

  # Execute our shadow's munge code, too, if we have one.
  # @todo BAFFLEGAB !
  #
  def munge(value)
    self.shadow.munge(value) if self.shadow

    super
  end

  # each property class must define the name method, and property instances
  # do not change that name
  # this implicitly means that a given object can only have one property
  # instance of a given property class
  def name
    self.class.name
  end

  # for testing whether we should actually do anything
  def noop
    # This is only here to make testing easier.
    if @resource.respond_to?(:noop?)
      @resource.noop?
    else
      if defined?(@noop)
        @noop
      else
        Puppet[:noop]
      end
    end
  end

  # By default, call the method associated with the property name on our
  # provider.  In other words, if the property name is 'gid', we'll call
  # 'provider.gid' to retrieve the current value.
  def retrieve
    provider.send(self.class.name)
  end

  # Set our value, using the provider, an associated block, or both.
  def set(value)
    # Set a name for looking up associated options like the event.
    name = self.class.value_name(value)

    call = self.class.value_option(name, :call) || :none

    if call == :instead
      call_valuemethod(name, value)
    elsif call == :none
      # They haven't provided a block, and our parent does not have
      # a provider, so we have no idea how to handle this.
      self.fail "#{self.class.name} cannot handle values of type #{value.inspect}" unless @resource.provider
      call_provider(value)
    else
      # LAK:NOTE 20081031 This is a change in behaviour -- you could
      # previously specify :call => [;before|:after], which would call
      # the setter *in addition to* the block.  I'm convinced this
      # was never used, and it makes things unecessarily complicated.
      # If you want to specify a block and still call the setter, then
      # do so in the block.
      devfail "Cannot use obsolete :call value '#{call}' for property '#{self.class.name}'"
    end
  end

  # If there's a shadowing metaparam, instantiate it now.
  # This allows us to create a property or parameter with the
  # same name as a metaparameter, and the metaparam will only be
  # stored as a shadow.
  def setup_shadow(klass)
    @shadow = klass.new(:resource => self.resource)
  end

  # Only return the first value
  def should
    return nil unless defined?(@should)

    self.devfail "should for #{self.class.name} on #{resource.name} is not an array" unless @should.is_a?(Array)

    if match_all?
      return @should.collect { |val| self.unmunge(val) }
    else
      return self.unmunge(@should[0])
    end
  end

  # Set the should value.
  def should=(values)
    values = [values] unless values.is_a?(Array)

    @shouldorig = values

    values.each { |val| validate(val) }
    @should = values.collect { |val| self.munge(val) }
  end

  def should_to_s(newvalue)
    [newvalue].flatten.join(" ")
  end

  def sync
    devfail "Got a nil value for should" unless should
    set(should)
  end

  # Verify that the passed value is valid.
  # If the developer uses a 'validate' hook, this method will get overridden.
  def unsafe_validate(value)
    super
    validate_features_per_value(value)
  end

  # Make sure that we've got all of the required features for a given value.
  def validate_features_per_value(value)
    if features = self.class.value_option(self.class.value_name(value), :required_features)
      features = Array(features)
      needed_features = features.collect { |f| f.to_s }.join(", ")
      raise ArgumentError, "Provider must have features '#{needed_features}' to set '#{self.class.name}' to '#{value}'" unless provider.satisfies?(features)
    end
  end

  # Just return any should value we might have.
  def value
    self.should
  end

  # Match the Parameter interface, but we really just use 'should' internally.
  # Note that the should= method does all of the validation and such.
  def value=(value)
    self.should = value
  end
end
