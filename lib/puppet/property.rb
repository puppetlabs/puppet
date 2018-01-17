# The virtual base class for properties, which are the self-contained building
# blocks for actually doing work on the system.

require 'puppet'
require 'puppet/parameter'

# The Property class is the implementation of a resource's attributes of _property_ kind.
# A Property is a specialized Resource Type Parameter that has both an 'is' (current) state, and
# a 'should' (wanted state). However, even if this is conceptually true, the current _is_ value is
# obtained by asking the associated provider for the value, and hence it is not actually part of a
# property's state, and only available when a provider has been selected and can obtain the value (i.e. when
# running on an agent).
#
# A Property (also in contrast to a parameter) is intended to describe a managed attribute of
# some system entity, such as the name or mode of a file.
#
# The current value _(is)_ is read and written with the methods {#retrieve} and {#set}, and the wanted
# value _(should)_ is read and written with the methods {#value} and {#value=} which delegate to
# {#should} and {#should=}, i.e. when a property is used like any other parameter, it is the _should_ value
# that is operated on.
#
# All resource type properties in the puppet system are derived from this class.
#
# The intention is that new parameters are created by using the DSL method {Puppet::Type.newproperty}.
#
# @abstract
# @note Properties of Types are expressed using subclasses of this class. Such a class describes one
#   named property of a particular Type (as opposed to describing a type of property in general). This
#   limits the use of one (concrete) property class instance to occur only once for a given type's inheritance
#   chain. An instance of a Property class is the value holder of one instance of the resource type (e.g. the
#   mode of a file resource instance).
#   A Property class may server as the superclass _(parent)_ of another; e.g. a Size property that describes
#   handling of measurements such as kb, mb, gb. If a type requires two different size measurements it requires
#   one concrete class per such measure; e.g. MinSize (:parent => Size), and MaxSize (:parent => Size).
#
# @see Puppet::Type
# @see Puppet::Parameter
#
# @api public
#
class Puppet::Property < Puppet::Parameter
  require 'puppet/property/ensure'

  # Returns the original wanted value(s) _(should)_ unprocessed by munging/unmunging.
  # The original values are set by {#value=} or {#should=}.
  # @return (see #should)
  #
  attr_reader :shouldorig

  # The noop mode for this property.
  # By setting a property's noop mode to `true`, any management of this property is inhibited. Calculation
  # and reporting still takes place, but if a change of the underlying managed entity's state
  # should take place it will not be carried out. This noop
  # setting overrides the overall `Puppet[:noop]` mode as well as the noop mode in the _associated resource_
  #
  attr_writer :noop

  class << self
    # @todo Figure out what this is used for. Can not find any logic in the puppet code base that
    #   reads or writes this attribute.
    # ??? Probably Unused
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
    # @note The semantics of these modes are implemented by the method {#insync?}. That method is the default
    #   implementation and it has a backwards compatible behavior that imposes additional constraints
    #   on what constitutes a positive match. A derived property may override that method.
    # @return [Symbol] (:first) the mode in which matching is performed
    # @see #insync?
    # @dsl type
    # @api public
    #
    def array_matching
      @array_matching ||= :first
    end

    # @comment This is documented as an attribute - see the {array_matching} method.
    #
    def array_matching=(value)
      value = value.intern if value.is_a?(String)
      #TRANSLATORS 'Property#array_matching', 'first', and 'all' should not be translated
      raise ArgumentError, _("Supported values for Property#array_matching are 'first' and 'all'") unless [:first, :all].include?(value)
      @array_matching = value
    end

    # Used to mark a type property as having or lacking idempotency (on purpose
    # generally). This is used to avoid marking the property as a
    # corrective_change when there is known idempotency issues with the property
    # rendering a corrective_change flag as useless.
    # @return [Boolean] true if the property is marked as idempotent
    def idempotent
      @idempotent.nil? ? @idempotent = true : @idempotent
    end

    # Attribute setter for the idempotent attribute.
    # @param [bool] value boolean indicating if the property is idempotent.
    # @see idempotent
    def idempotent=(value)
      @idempotent = value
    end
  end

  # Looks up a value's name among valid values, to enable option lookup with result as a key.
  # @param name [Object] the parameter value to match against valid values (names).
  # @return {Symbol, Regexp} a value matching predicate
  # @api private
  #
  def self.value_name(name)
    if value = value_collection.match?(name)
      value.name
    end
  end

  # Returns the value of the given option (set when a valid value with the given "name" was defined).
  # @param name [Symbol, Regexp] the valid value predicate as returned by {value_name}
  # @param option [Symbol] the name of the wanted option
  # @return [Object] value of the option
  # @raise [NoMethodError] if the option is not supported
  # @todo Guessing on result of passing a non supported option (it performs send(option)).
  # @api private
  #
  def self.value_option(name, option)
    if value = value_collection.value(name)
      value.send(option)
    end
  end

  # Defines a new valid value for this property.
  # A valid value is specified as a literal (typically a Symbol), but can also be
  # specified with a Regexp.
  #
  # @param name [Symbol, Regexp] a valid literal value, or a regexp that matches a value
  # @param options [Hash] a hash with options
  # @option options [Symbol] :event The event that should be emitted when this value is set.
  # @todo Option :event original comment says "event should be returned...", is "returned" the correct word
  #   to use?
  # @option options [Symbol] :invalidate_refreshes Indicates a change on this property should invalidate and
  #   remove any scheduled refreshes (from notify or subscribe) targeted at the same resource. For example, if
  #   a change in this property takes into account any changes that a scheduled refresh would have performed,
  #   then the scheduled refresh would be deleted.
  # @option options [Object] any Any other option is treated as a call to a setter having the given
  #   option name (e.g. `:required_features` calls `required_features=` with the option's value as an
  #   argument).
  #
  # @dsl type
  # @api public
  def self.newvalue(name, options = {}, &block)
    value = value_collection.newvalue(name, options, &block)

    unless value.method.nil?
      method = value.method.to_sym
      if value.block
        if instance_methods(false).include?(method)
          raise ArgumentError, _("Attempt to redefine method %{method} with block") % { method: method }
        end
        define_method(method, &value.block)
      else
        # Let the method be an alias for calling the providers setter unless we already have this method
        alias_method(method, :call_provider) unless method_defined?(method)
      end
    end
    value
  end

  # Calls the provider setter method for this property with the given value as argument.
  # @return [Object] what the provider returns when calling a setter for this property's name
  # @raise [Puppet::Error] when the provider can not handle this property.
  # @see #set
  # @api private
  #
  def call_provider(value)
    # We have no idea how to handle this unless our parent have a provider
    self.fail "#{self.class.name} cannot handle values of type #{value.inspect}" unless @resource.provider
    method = self.class.name.to_s + "="
    unless provider.respond_to? method
      self.fail "The #{provider.class.name} provider can not handle attribute #{self.class.name}"
    end
    provider.send(method, value)
  end

  # Formats a message for a property change from the given `current_value` to the given `newvalue`.
  # @return [String] a message describing the property change.
  # @note If called with equal values, this is reported as a change.
  # @raise [Puppet::DevError] if there were issues formatting the message
  #
  def change_to_s(current_value, newvalue)
    begin
      if current_value == :absent
        return "defined '#{name}' as #{should_to_s(newvalue)}"
      elsif newvalue == :absent or newvalue == [:absent]
        return "undefined '#{name}' from #{is_to_s(current_value)}"
      else
        return "#{name} changed #{is_to_s(current_value)} to #{should_to_s(newvalue)}"
      end
    rescue Puppet::Error, Puppet::DevError
      raise
    rescue => detail
      message = _("Could not convert change '%{name}' to string: %{detail}") % { name: name, detail: detail }
      Puppet.log_exception(detail, message)
      raise Puppet::DevError, message, detail.backtrace
    end
  end

  # Produces the name of the event to use to describe a change of this property's value.
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

  # Produces an event describing a change of this property.
  # In addition to the event attributes set by the resource type, this method adds:
  #
  # * `:name` - the event_name
  # * `:desired_value` - a.k.a _should_ or _wanted value_
  # * `:property` - reference to this property
  # * `:source_description` - The containment path of this property, indicating what resource this
  #                           property is associated with and in what stage and class that resource
  #                           was declared, e.g. "/Stage[main]/Myclass/File[/tmp/example]/ensure"
  # * `:invalidate_refreshes` - if scheduled refreshes should be invalidated
  # * `:redacted` - if the event will be redacted (due to this property being sensitive)
  #
  # @return [Puppet::Transaction::Event] the created event
  # @see Puppet::Type#event
  def event(options = {})
    attrs = { :name => event_name, :desired_value => should, :property => self, :source_description => path }.merge(options)
    if should and value = self.class.value_collection.match?(should)
      attrs[:invalidate_refreshes] = true if value.invalidate_refreshes
    end
    attrs[:redacted] = @sensitive
    resource.event attrs
  end

  # Determines whether the property is in-sync or not in a way that is protected against missing value.
  # @note If the wanted value _(should)_ is not defined or is set to a non-true value then this is
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
  # @raise [RuntimeError] if the added method is `:safe_insync?`
  # @api private
  #
  def self.method_added(sym)
    raise "Puppet::Property#safe_insync? shouldn't be overridden; please override insync? instead" if sym == :safe_insync?
  end

  # Checks if the current _(is)_ value is in sync with the wanted _(should)_ value.
  # The check if the two values are in sync is controlled by the result of {#match_all?} which
  # specifies a match of `:first` or `:all`). The matching of the _is_ value against the entire _should_ value
  # or each of the _should_ values (as controlled by {#match_all?} is performed by {#property_matches?}.
  #
  # A derived property typically only needs to override the {#property_matches?} method, but may also
  # override this method if there is a need to have more control over the array matching logic.
  #
  # @note The array matching logic in this method contains backwards compatible logic that performs the
  #   comparison in `:all` mode by checking equality and equality of _is_ against _should_ converted to array of String,
  #   and that the lengths are equal, and in `:first` mode by checking if one of the _should_ values
  #   is included in the _is_ values. This means that the _is_ value needs to be carefully arranged to
  #   match the _should_.
  # @todo The implementation should really do return is.zip(@should).all? {|a, b| property_matches?(a, b) }
  #   instead of using equality check and then check against an array with converted strings.
  # @param is [Object] The current _(is)_ value to check if it is in sync with the wanted _(should)_ value(s)
  # @return [Boolean] whether the values are in sync or not.
  # @raise [Puppet::DevError] if wanted value _(should)_ is not an array.
  # @api public
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

  # This method tests if two values are insync? outside of the properties current
  # should value. This works around the requirement for corrective_change analysis
  # that requires two older values to be compared with the properties potentially
  # custom insync? code.
  #
  # @param [Object] should the value it should be
  # @param [Object] is the value it is
  # @return [Boolean] whether or not the values are in sync or not
  # @api private
  def insync_values?(should, is)
    # Here be dragons. We're setting the should value of a property purely just to
    # call its insync? method, as it lacks a way to pass in a should.
    # Unfortunately there isn't an API compatible way of avoiding this, as both should
    # an insync? behaviours are part of the public API. Future API work should factor
    # this kind of arbitrary comparisons into the API to remove this complexity. -ken

    # Backup old should, set it to the new value, then call insync? on the property.
    old_should = @should

    begin
      @should = should
      insync?(is)
    rescue
      # Certain operations may fail, but we don't want to fail the transaction if we can
      # avoid it
      #TRANSLATORS 'insync_values?' should not be translated
      msg = _("Unknown failure using insync_values? on type: %{type} / property: %{name} to compare values %{should} and %{is}") %
          { type: self.resource.ref, name: self.name, should: should, is: is }
      Puppet.info(msg)

      # Return nil, ie. unknown
      nil
    ensure
      # Always restore old should
      @should = old_should
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
  # This default implementation calls {#format_value_for_display} on the class. A derived
  # implementation may perform property specific pretty printing when the _is_ values
  # are not already in suitable form.
  # @param value [Object] the value to format as a string
  # @return [String] a pretty printing string
  def is_to_s(value)
    self.class.format_value_for_display(value)
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

  # @return [Boolean] whether the property is marked as idempotent for the purposes
  #   of calculating corrective change.
  def idempotent?
    self.class.idempotent
  end

  # @return [Symbol] the name of the property as stated when the property was created.
  # @note A property class (just like a parameter class) describes one specific property and
  #   can only be used once within one type's inheritance chain.
  def name
    self.class.name
  end

  # @return [Boolean] whether this property is in noop mode or not.
  # Returns whether this property is in noop mode or not; if a difference between the
  # _is_ and _should_ values should be acted on or not.
  # The noop mode is a transitive setting. The mode is checked in this property, then in
  # the _associated resource_ and finally in Puppet[:noop].
  # @todo This logic is different than Parameter#noop in that the resource noop mode overrides
  #   the property's mode - in parameter it is the other way around. Bug or feature?
  #
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

  # Retrieves the current value _(is)_ of this property from the provider.
  # This implementation performs this operation by calling a provider method with the
  # same name as this property (i.e. if the property name is 'gid', a call to the
  # 'provider.gid' is expected to return the current value.
  # @return [Object] what the provider returns as the current value of the property
  #
  def retrieve
    provider.send(self.class.name)
  end

  # Sets the current _(is)_ value of this property.
  # The _name_ associated with the value is first obtained by calling {value_name}. A dynamically created setter
  # method associated with this _name_ is called if it exists, otherwise the value is set using using the provider's
  # setter method for this property by calling ({#call_provider}).
  #
  # @param value [Object] the value to set
  # @return [Object] returns the result of calling the setter method or {#call_provider}
  # @raise [Puppet::Error] if there were problems setting the value using the setter method or when the provider
  #  setter should be used but there is no provider in the associated resource_
  # @raise [Puppet::ResourceError] if there was a problem setting the value and it was not raised
  #   as a Puppet::Error. The original exception is wrapped and logged.
  # @api public
  #
  def set(value)
    # Set a name for looking up associated options like the event.
    name = self.class.value_name(value)
    if method = self.class.value_option(name, :method) and self.respond_to?(method)
      begin
        self.send(method)
      rescue Puppet::Error
        raise
      rescue => detail
        error = Puppet::ResourceError.new(_("Could not set '%{value}' on %{class_name}: %{detail}") %
                                              { value: value, class_name: self.class.name, detail: detail }, @resource.file, @resource.line, detail)
        error.set_backtrace detail.backtrace
        Puppet.log_exception(detail, error.message)
        raise error
      end
    elsif block = self.class.value_option(name, :block)
      # FIXME It'd be better here to define a method, so that
      # the blocks could return values.
      self.instance_eval(&block)
    else
      call_provider(value)
    end
  end

  # Returns the wanted _(should)_ value of this property.
  # If the _array matching mode_ {#match_all?} is true, an array of the wanted values in unmunged format
  # is returned, else the first value in the array of wanted values in unmunged format is returned.
  # @return [Array<Object>, Object, nil] Array of values if {#match_all?} else a single value, or nil if there are no
  #   wanted values.
  # @raise [Puppet::DevError] if the wanted value is non nil and not an array
  #
  # @note This method will potentially return different values than the original values as they are
  #   converted via munging/unmunging. If the original values are wanted, call {#shouldorig}.
  #
  # @see #shouldorig
  # @api public
  #
  def should
    return nil unless defined?(@should)

    self.devfail "should for #{self.class.name} on #{resource.name} is not an array" unless @should.is_a?(Array)

    if match_all?
      return @should.collect { |val| self.unmunge(val) }
    else
      return self.unmunge(@should[0])
    end
  end

  # Sets the wanted _(should)_ value of this property.
  # If the given value is not already an Array, it will be wrapped in one before being set.
  # This method also sets the cached original _should_ values returned by {#shouldorig}.
  #
  # @param values [Array<Object>, Object] the value(s) to set as the wanted value(s)
  # @raise [StandardError] when validation of a value fails (see {#validate}).
  # @api public
  #
  def should=(values)
    values = [values] unless values.is_a?(Array)

    @shouldorig = values

    values.each { |val| validate(val) }
    @should = values.collect { |val| self.munge(val) }
  end

  # Produces a pretty printing string for the given value.
  # This default implementation calls {#format_value_for_display} on the class. A derived
  # implementation may perform property specific pretty printing when the _should_ values
  # are not already in suitable form.
  # @param value [Object] the value to format as a string
  # @return [String] a pretty printing string
  def should_to_s(value)
    self.class.format_value_for_display(value)
  end

  # Synchronizes the current value _(is)_ and the wanted value _(should)_ by calling {#set}.
  # @raise [Puppet::DevError] if {#should} is nil
  # @todo The implementation of this method is somewhat inefficient as it computes the should
  #  array twice.
  def sync
    devfail "Got a nil value for should" unless should
    set(should)
  end

  # Asserts that the given value is valid.
  # If the developer uses a 'validate' hook, this method will get overridden.
  # @raise [Exception] if the value is invalid, or value can not be handled.
  # @return [void]
  # @api private
  #
  def unsafe_validate(value)
    super
    validate_features_per_value(value)
  end

  # Asserts that all required provider features are present for the given property value.
  # @raise [ArgumentError] if a required feature is not present
  # @return [void]
  # @api private
  #
  def validate_features_per_value(value)
    if features = self.class.value_option(self.class.value_name(value), :required_features)
      features = Array(features)
      needed_features = features.collect { |f| f.to_s }.join(", ")
      unless provider.satisfies?(features)
        #TRANSLATORS 'Provider' refers to a Puppet provider class
        raise ArgumentError, _("Provider %{provider} must have features '%{needed_features}' to set '%{property}' to '%{value}'") %
            { provider: provider.class.name, needed_features: needed_features, property: self.class.name, value: value }
      end
    end
  end

  # @return [Object, nil] Returns the wanted _(should)_ value of this property.
  def value
    self.should
  end

  # (see #should=)
  def value=(values)
    self.should = values
  end
end
