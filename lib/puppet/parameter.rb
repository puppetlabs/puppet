require 'puppet/util/methodhelper'
require 'puppet/util/logging'
require 'puppet/util/docs'

# The Parameter class is the implementation of a resource's attributes of _parameter_ kind.
# The Parameter class is also the base class for {Puppet::Property}, and is used to describe meta-parameters
# (parameters that apply to all resource types).
# A Parameter (in contrast to a Property) has a single value where a property has both a current and a wanted value.
# The Parameter class methods are used to configure and create an instance of Parameter that represents
# one particular attribute data type; its valid value(s), and conversion to/from internal form.
#
# The intention is that a new parameter is created by using the DSL method {Puppet::Type.newparam}, or
# {Puppet::Type.newmetaparam} if the parameter should be applicable to all resource types.
#
# A Parameter that does not specify and valid values (via {newvalues}) accepts any value.
#
# @see Puppet::Type
# @see Puppet::Property
# @api public
#
class Puppet::Parameter
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::Logging
  include Puppet::Util::MethodHelper

  require 'puppet/parameter/value_collection'

  class << self
    include Puppet::Util
    include Puppet::Util::Docs

    # @return [Symbol] The parameter name as given when it was created.
    attr_reader :name

    # @return [Object] The default value of the parameter as determined by the {defaultto} method, or nil if no
    #  default has been set.
    attr_reader :default

    # @comment This somewhat odd documentation construct is because the getter and setter are not
    #  orthogonal; the setter uses varargs and this confuses yard. To overcome the problem both the
    #  getter and the setter are documented here. If this issues is fixed, a todo will be displayed
    #  for the setter method, and the setter documentation can be moved there.
    #  Since the attribute is actually RW it should  perhaps instead just be implemented as a setter
    #  and a getter method (and no attr_xxx declaration).
    #
    # @!attribute [rw] required_features
    # @return [Array<Symbol>] The names of the _provider features_ required for this parameter to work.
    #   the returned names are always all lower case symbols.
    # @overload required_features
    #   Returns the required _provider features_ as an array of lower case symbols
    # @overload required_features=(*args)
    #   @param *args [Symbol] one or more names of required provider features
    #   Sets the required_provider_features_ from one or more values, or array. The given arguments
    #   are flattened, and internalized.
    # @api public
    # @dsl type
    #
    attr_reader :required_features

    # @return [Puppet::Parameter::ValueCollection] The set of valid values (or an empty set that accepts any value).
    # @api private
    #
    attr_reader :value_collection

    # @return [Boolean] Flag indicating whether this parameter is a meta-parameter or not.
    attr_accessor :metaparam

    # Defines how the `default` value of a parameter is computed.
    # The computation of the parameter's default value is defined by providing a value or a block.
    # A default of `nil` can not be used.
    # @overload defaultto(value)
    #   Defines the default value with a literal value
    #   @param value [Object] the literal value to use as the default value
    # @overload defaultto({|| ... })
    #   Defines that the default value is produced by the given block. The given block
    #   should produce the default value.
    # @raise [Puppet::DevError] if value is nil, and no block is given.
    # @return [void]
    # @see Parameter.default
    # @dsl type
    # @api public
    #
    def defaultto(value = nil, &block)
      if block
        define_method(:default, &block)
      else
        if value.nil?
          raise Puppet::DevError,
            "Either a default value or block must be provided"
        end
        define_method(:default) do value end
      end
    end

    # Produces a documentation string.
    # If an enumeration of _valid values_ has been defined, it is appended to the documentation
    # for this parameter specified with the {desc} method.
    # @return [String] Returns a documentation string.
    # @api public
    #
    def doc
      @doc ||= ""

      unless defined?(@addeddocvals)
        @doc = Puppet::Util::Docs.scrub(@doc)
        if vals = value_collection.doc
          @doc << "\n\n#{vals}"
        end

        if features = self.required_features
          @doc << "\n\nRequires features #{features.flatten.collect { |f| f.to_s }.join(" ")}."
        end
        @addeddocvals = true
      end

      @doc
    end

    # Removes the `default` method if defined.
    # Has no effect if the default method is not defined.
    # This method is intended to be used in a DSL scenario where a parameter inherits from a parameter
    # with a default value that is not wanted in the derived parameter (otherwise, simply do not define
    # a default value method).
    #
    # @return [void]
    # @see desc
    # @api public
    # @dsl type
    #
    def nodefault
      undef_method :default if public_method_defined? :default
    end

    # Sets the documentation for this parameter.
    # @param str [String] The documentation string to set
    # @return [String] the given `str` parameter
    # @see doc
    # @dsl type
    # @api public
    #
    def desc(str)
      @doc = str
    end

    # Initializes the instance variables.
    # Clears the internal value collection (set of allowed values).
    # @return [void]
    # @api private
    #
    def initvars
      @value_collection = ValueCollection.new
    end

    # @overload munge {|| ... }
    # Defines an optional method used to convert the parameter value from DSL/string form to an internal form.
    # If a munge method is not defined, the DSL/string value is used as is.
    # @note This adds a method with the name `unsafe_munge` in the created parameter class. Later this method is
    #   called in a context where exceptions will be rescued and handled.
    # @dsl type
    # @api public
    #
    def munge(&block)
      # I need to wrap the unsafe version in begin/rescue parameterments,
      # but if I directly call the block then it gets bound to the
      # class's context, not the instance's, thus the two methods,
      # instead of just one.
      define_method(:unsafe_munge, &block)
    end

    # @overload unmunge {|| ... }
    # Defines an optional method used to convert the parameter value to DSL/string form from an internal form.
    # If an `unmunge` method is not defined, the internal form is used.
    # @see munge
    # @note This adds a method with the name `unmunge` in the created parameter class.
    # @dsl type
    # @api public
    #
    def unmunge(&block)
      define_method(:unmunge, &block)
    end

    # Sets a marker indicating that this parameter is the _namevar_ (unique identifier) of the type
    # where the parameter is contained.
    # This also makes the parameter a required value. The marker can not be unset once it has been set.
    # @return [void]
    # @dsl type
    # @api public
    #
    def isnamevar
      @isnamevar = true
      @required = true
    end

    # @return [Boolean] Returns whether this parameter is the _namevar_ or not.
    # @api public
    #
    def isnamevar?
      @isnamevar
    end

    # Sets a marker indicating that this parameter is required.
    # Once set, it is not possible to make a parameter optional.
    # @return [void]
    # @dsl type
    # @api public
    #
    def isrequired
      @required = true
    end

    # @comment This method is not picked up by yard as it has a different signature than
    #   expected for an attribute (varargs). Instead, this method is documented as an overload
    #   of the attribute required_features. (Not ideal, but better than nothing).
    # @todo If this text appears in documentation - see comment in source and makes corrections - it means
    #   that an issue in yardoc has been fixed.
    #
    def required_features=(*args)
      @required_features = args.flatten.collect { |a| a.to_s.downcase.intern }
    end

    # Returns whether this parameter is required or not.
    # A parameter is required if a call has been made to the DSL method {isrequired}.
    # @return [Boolean] Returns whether this parameter is required or not.
    # @api public
    #
    def required?
      @required
    end

    # @overload validate {|| ... }
    # Defines an optional method that is used to validate the parameter's DSL/string value.
    # Validation should raise appropriate exceptions, the return value of the given block is ignored.
    # The easiest way to raise an appropriate exception is to call the method {Puppet::Util::Errors.fail} with
    # the message as an argument.
    # To validate the munged value instead, just munge the value (`munge(value)`).
    #
    # @return [void]
    # @dsl type
    # @api public
    #
    def validate(&block)
      define_method(:unsafe_validate, &block)
    end

    # Defines valid values for the parameter (enumeration or regular expressions).
    # The set of valid values for the parameter can be limited to a (mix of) literal values and
    # regular expression patterns.
    # @note Each call to this method adds to the set of valid values
    # @param names [Symbol, Regexp] The set of valid literal values and/or patterns for the parameter.
    # @return [void]
    # @dsl type
    # @api public
    #
    def newvalues(*names)
      @value_collection.newvalues(*names)
    end

    # Makes the given `name` an alias for the given `other` name.
    # Or said differently, the valid value `other` can now also be referred to via the given `name`.
    # Aliasing may affect how the parameter's value is serialized/stored (it may store the `other` value
    # instead of the alias).
    # @api public
    # @dsl type
    #
    def aliasvalue(name, other)
      @value_collection.aliasvalue(name, other)
    end
  end

  # Creates instance (proxy) methods that delegates to a class method with the same name.
  # @api private
  #
  def self.proxymethods(*values)
    values.each { |val|
      define_method(val) do
        self.class.send(val)
      end
    }
  end

  # @!method required?
  #   (see required?)
  # @!method isnamevar?
  #   (see isnamevar?)
  #
  proxymethods("required?", "isnamevar?")

  # @return [Puppet::Resource] A reference to the resource this parameter is an attribute of (the _associated resource_).
  attr_accessor :resource

  # @comment LAK 2007-05-09: Keep the @parent around for backward compatibility.
  # @return [Puppet::Parameter] A reference to the parameter's parent kept for backwards compatibility.
  # @api private
  #
  attr_accessor :parent

  # Returns a string representation of the resource's containment path in
  # the catalog.
  # @return [String]
  def path
    @path ||= '/' + pathbuilder.join('/')
  end

  # @return [Integer] Returns the result of calling the same method on the associated resource.
  def line
    resource.line
  end

  # @return [Integer] Returns the result of calling the same method on the associated resource.
  def file
    resource.file
  end

  # @return [Integer] Returns the result of calling the same method on the associated resource.
  def version
    resource.version
  end


  # Initializes the parameter with a required resource reference and optional attribute settings.
  # The option `:resource` must be specified or an exception is raised. Any additional options passed
  # are used to initialize the attributes of this parameter by treating each key in the `options` hash as
  # the name of the attribute to set, and the value as the value to set.
  # @param options [Hash{Symbol => Object]] Options, where `resource` is required
  # @option options [Puppet::Resource] :resource The resource this parameter holds a value for. Required.
  # @raise [Puppet::DevError] If resource is not specified in the options hash.
  # @api public
  # @note A parameter should be created via the DSL method {Puppet::Type::newparam}
  #
  def initialize(options = {})
    options = symbolize_options(options)
    if resource = options[:resource]
      self.resource = resource
      options.delete(:resource)
    else
      raise Puppet::DevError, "No resource set for #{self.class.name}"
    end

    set_options(options)
  end

  # Writes the given `msg` to the log with the loglevel indicated by the associated resource's
  # `loglevel` parameter.
  # @todo is loglevel a metaparameter? it is looked up with `resource[:loglevel]`
  # @return [void]
  # @api public
  def log(msg)
    send_log(resource[:loglevel], msg)
  end

  # @return [Boolean] Returns whether this parameter is a meta-parameter or not.
  def metaparam?
    self.class.metaparam
  end

  # @!attribute [r] name
  # @return [Symbol] The parameter's name as given when it was created.
  # @note Since a Parameter defines the name at the class level, each Parameter class must be
  #  unique within a type's inheritance chain.
  # @comment each parameter class must define the name method, and parameter
  #   instances do not change that name this implicitly means that a given
  #   object can only have one parameter instance of a given parameter
  #   class
  def name
    self.class.name
  end

  # @return [Boolean] Returns true if this parameter, the associated resource, or overall puppet mode is `noop`.
  # @todo How is noop mode set for a parameter? Is this of value in DSL to inhibit a parameter?
  #
  def noop
    @noop ||= false
    tmp = @noop || self.resource.noop || Puppet[:noop] || false
    #debug "noop is #{tmp}"
    tmp
  end

  # Returns an array of strings representing the containment hierarchy
  # (types/classes) that make up the path to the resource from the root
  # of the catalog.  This is mostly used for logging purposes.
  #
  # @api private
  def pathbuilder
    if @resource
      return [@resource.pathbuilder, self.name]
    else
      return [self.name]
    end
  end

  # This is the default implementation of `munge` that simply produces the value (if it is valid).
  # The DSL method {munge} should be used to define an overriding method if munging is required.
  #
  # @api private
  #
  def unsafe_munge(value)
    self.class.value_collection.munge(value)
  end

  # Unmunges the value by transforming it from internal form to DSL form.
  # This is the default implementation of `unmunge` that simply returns the value without processing.
  # The DSL method {unmunge} should be used to define an overriding method if required.
  # @return [Object] the unmunged value
  #
  def unmunge(value)
    value
  end

  # Munges the value to internal form.
  # This implementation of `munge` provides exception handling around the specified munging of this parameter.
  # @note This method should not be overridden. Use the DSL method {munge} to define a munging method
  #   if required.
  # @param value [Object] the DSL value to munge
  # @return [Object] the munged (internal) value
  #
  def munge(value)
    begin
      ret = unsafe_munge(value)
    rescue Puppet::Error => detail
      Puppet.debug "Reraising #{detail}"
      raise
    rescue => detail
      raise Puppet::DevError, "Munging failed for value #{value.inspect} in class #{self.name}: #{detail}", detail.backtrace
    end
    ret
  end

  # This is the default implementation of `validate` that may be overridden by the DSL method {validate}.
  # If no valid values have been defined, the given value is accepted, else it is validated against
  # the literal values (enumerator) and/or patterns defined by calling {newvalues}.
  #
  # @param value [Object] the value to check for validity
  # @raise [ArgumentError] if the value is not valid
  # @return [void]
  # @api private
  #
  def unsafe_validate(value)
    self.class.value_collection.validate(value)
  end

  # Performs validation of the given value against the rules defined by this parameter.
  # @return [void]
  # @todo Better description of when the various exceptions are raised.ArgumentError is rescued and
  #   changed into Puppet::Error.
  # @raise [ArgumentError, TypeError, Puppet::DevError, Puppet::Error] under various conditions
  # A protected validation method that only ever raises useful exceptions.
  # @api public
  #
  def validate(value)
    begin
      unsafe_validate(value)
    rescue ArgumentError => detail
      self.fail Puppet::Error, detail.to_s, detail
    rescue Puppet::Error, TypeError
      raise
    rescue => detail
      raise Puppet::DevError, "Validate method failed for class #{self.name}: #{detail}", detail.backtrace
    end
  end

  # Sets the associated resource to nil.
  # @todo Why - what is the intent/purpose of this?
  # @return [nil]
  #
  def remove
    @resource = nil
  end

  # @return [Object] Gets the value of this parameter after performing any specified unmunging.
  def value
    unmunge(@value) unless @value.nil?
  end

  # Sets the given value as the value of this parameter.
  # @todo This original comment _"All of the checking should possibly be
  #   late-binding (e.g., users might not exist when the value is assigned
  #   but might when it is asked for)."_ does not seem to be correct, the implementation
  #   calls both validate and munge on the given value, so no late binding.
  #
  # The given value is validated and then munged (if munging has been specified). The result is store
  # as the value of this parameter.
  # @return [Object] The given `value` after munging.
  # @raise (see #validate)
  #
  def value=(value)
    validate(value)

    @value = munge(value)
  end

  # @return [Puppet::Provider] Returns the provider of the associated resource.
  # @todo The original comment says = _"Retrieve the resource's provider.
  #   Some types don't have providers, in which case we return the resource object itself."_
  #   This does not seem to be true, the default implementation that sets this value may be
  #   {Puppet::Type.provider=} which always gets either the name of a provider or an instance of one.
  #
  def provider
    @resource.provider
  end

  # @return [Array<Symbol>] Returns an array of the associated resource's symbolic tags (including the parameter itself).
  # Returns an array of the associated resource's symbolic tags (including the parameter itself).
  # At a minimum, the array contains the name of the parameter. If the associated resource
  # has tags, these tags are also included in the array.
  # @todo The original comment says = _"The properties need to return tags so that logs correctly
  #   collect them."_ what if anything of that is of interest to document. Should tags and their relationship
  #   to logs be described. This is a more general concept.
  #
  def tags
    unless defined?(@tags)
      @tags = []
      # This might not be true in testing
      @tags = @resource.tags if @resource.respond_to? :tags
      @tags << self.name.to_s
    end
    @tags
  end

  # @return [String] The name of the parameter in string form.
  def to_s
    name.to_s
  end

  # Produces a String with the value formatted for display to a human.
  # When the parameter value is a:
  #
  # * **single valued parameter value** the result is produced on the
  #   form `'value'` where _value_ is the string form of the parameter's value.
  #
  # * **Array** the list of values is enclosed in `[]`, and
  #   each produced value is separated by a comma.
  #
  # * **Hash** value is output with keys in sorted order enclosed in `{}` with each entry formatted
  #   on the form `'k' => v` where
  #   `k` is the key in string form and _v_ is the value of the key. Entries are comma separated.
  #
  # For both Array and Hash this method is called recursively to format contained values.
  # @note this method does not protect against infinite structures.
  #
  # @return [String] The formatted value in string form.
  #
  def self.format_value_for_display(value)
    if value.is_a? Array
      formatted_values = value.collect {|v| format_value_for_display(v)}.join(', ')
      "[#{formatted_values}]"
    elsif value.is_a? Hash
      # Sorting the hash keys for display is largely for having stable
      # output to test against, but also helps when scanning for hash
      # keys, since they will be in ASCIIbetical order.
      hash = value.keys.sort {|a,b| a.to_s <=> b.to_s}.collect do |k|
        "'#{k}' => #{format_value_for_display(value[k])}"
      end.join(', ')

      "{#{hash}}"
    else
      "'#{value}'"
    end
  end

  # @comment Document post_compile_hook here as it does not exist anywhere (called from type if implemented)
  # @!method post_compile()
  # @since 3.4.0
  # @api public
  #   @abstract A subclass may implement this - it is not implemented in the Parameter class
  #   This method may be implemented by a parameter in order to perform actions during compilation
  #   after all resources have been added to the catalog.
  #   @see Puppet::Type#finish
  #   @see Puppet::Parser::Compiler#finish
end

require 'puppet/parameter/path'
