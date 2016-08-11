# -*- coding: utf-8 -*-
require 'puppet'
require 'puppet/util/log'
require 'puppet/util/metric'
require 'puppet/property'
require 'puppet/parameter'
require 'puppet/util'
require 'puppet/util/autoload'
require 'puppet/metatype/manager'
require 'puppet/util/errors'
require 'puppet/util/logging'
require 'puppet/util/tagging'

# see the bottom of the file for the rest of the inclusions


module Puppet
# The base class for all Puppet types.
#
# A type describes:
#--
# * **Attributes** - properties, parameters, and meta-parameters are different types of attributes of a type.
#   * **Properties** - these are the properties of the managed resource (attributes of the entity being managed; like
#     a file's owner, group and mode). A property describes two states; the 'is' (current state) and the 'should' (wanted
#     state).
#       * **Ensurable** - a set of traits that control the lifecycle (create, remove, etc.) of a managed entity.
#         There is a default set of operations associated with being _ensurable_, but this can be changed.
#       * **Name/Identity** - one property is the name/identity of a resource, the _namevar_ that uniquely identifies
#         one instance of a type from all others.
#   * **Parameters** - additional attributes of the type (that does not directly related to an instance of the managed
#     resource; if an operation is recursive or not, where to look for things, etc.). A Parameter (in contrast to Property)
#     has one current value where a Property has two (current-state and wanted-state).
#   * **Meta-Parameters** - parameters that are available across all types. A meta-parameter typically has
#     additional semantics; like the `require` meta-parameter. A new type typically does not add new meta-parameters,
#     but you need to be aware of their existence so you do not inadvertently shadow an existing meta-parameters.
# * **Parent** - a type can have a super type (that it inherits from).
# * **Validation** - If not just a basic data type, or an enumeration of symbolic values, it is possible to provide
#     validation logic for a type, properties and parameters.
# * **Munging** - munging/unmunging is the process of turning a value in external representation (as used
#     by a provider) into an internal representation and vice versa. A Type supports adding custom logic for these.
# * **Auto Requirements** - a type can specify automatic relationships to resources to ensure that if they are being
#     managed, they will be processed before this type.
# * **Providers** - a provider is an implementation of a type's behavior - the management of a resource in the
#     system being managed. A provider is often platform specific and is selected at runtime based on
#     criteria/predicates specified in the configured providers. See {Puppet::Provider} for details.
# * **Device Support** - A type has some support for being applied to a device; i.e. something that is managed
#     by running logic external to the device itself. There are several methods that deals with type
#     applicability for these special cases such as {apply_to_device}.
#
# Additional Concepts:
# --
# * **Resource-type** - A _resource type_ is a term used to denote the type of a resource; internally a resource
#     is really an instance of a Ruby class i.e. {Puppet::Resource} which defines its behavior as "resource data".
#     Conceptually however, a resource is an instance of a subclass of Type (e.g. File), where such a class describes
#     its interface (what can be said/what is known about a resource of this type),
# * **Managed Entity** - This is not a term in general use, but is used here when there is a need to make
#     a distinction between a resource (a description of what/how something should be managed), and what it is
#     managing (a file in the file system). The term _managed entity_ is a reference to the "file in the file system"
# * **Isomorphism** - the quality of being _isomorphic_ means that two resource instances with the same name
#     refers to the same managed entity. Or put differently; _an isomorphic name is the identity of a resource_.
#     As an example, `exec` resources (that executes some command) have the command (i.e. the command line string) as
#     their name, and these resources are said to be non-isomorphic.
#
# @note The Type class deals with multiple concerns; some methods provide an internal DSL for convenient definition
#   of types, other methods deal with various aspects while running; wiring up a resource (expressed in Puppet DSL)
#   with its _resource type_ (i.e. an instance of Type) to enable validation, transformation of values
#   (munge/unmunge), etc. Lastly, Type is also responsible for dealing with Providers; the concrete implementations
#   of the behavior that constitutes how a particular Type behaves on a particular type of system (e.g. how
#   commands are executed on a flavor of Linux, on Windows, etc.). This means that as you are reading through the
#   documentation of this class, you will be switching between these concepts, as well as switching between
#   the conceptual level "a resource is an instance of a resource-type" and the actual implementation classes
#   (Type, Resource, Provider, and various utility and helper classes).
#
# @api public
#
#
class Type
  extend Puppet::CompilableResourceType
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::Logging
  include Puppet::Util::Tagging

  # Comparing type instances.
  include Comparable

  # Compares this type against the given _other_ (type) and returns -1, 0, or +1 depending on the order.
  # @param other [Object] the object to compare against (produces nil, if not kind of Type}
  # @return [-1, 0, +1, nil] produces -1 if this type is before the given _other_ type, 0 if equals, and 1 if after.
  #   Returns nil, if the given _other_ is not a kind of Type.
  # @see Comparable
  #
  def <=>(other)
    # Order is only maintained against other types, not arbitrary objects.
    # The natural order is based on the reference name used when comparing
    return nil unless other.is_a?(Puppet::CompilableResourceType) || other.class.is_a?(Puppet::CompilableResourceType)
    # against other type instances.
    self.ref <=> other.ref
  end

  # Code related to resource type attributes.
  class << self
    include Puppet::Util::ClassGen
    include Puppet::Util::Warnings

    # @return [Array<Puppet::Property>] The list of declared properties for the resource type.
    # The returned lists contains instances if Puppet::Property or its subclasses.
    attr_reader :properties
  end

  # Allow declaring that a type is actually a capability
  class << self
    attr_accessor :is_capability

    def is_capability?
      is_capability
    end
  end

  # Returns whether this type represents an application instance; since
  # only defined types, i.e., instances of Puppet::Resource::Type can
  # represent application instances, this implementation always returns
  # +false+. Having this method though makes code checking whether a
  # resource is an application instance simpler
  def self.application?
      false
  end

  # Returns all the attribute names of the type in the appropriate order.
  # The {key_attributes} come first, then the {provider}, then the {properties}, and finally
  # the {parameters} and {metaparams},
  # all in the order they were specified in the respective files.
  # @return [Array<String>] all type attribute names in a defined order.
  #
  def self.allattrs
    key_attributes | (parameters & [:provider]) | properties.collect { |property| property.name } | parameters | metaparams
  end

  # Returns the class associated with the given attribute name.
  # @param name [String] the name of the attribute to obtain the class for
  # @return [Class, nil] the class for the given attribute, or nil if the name does not refer to an existing attribute
  #
  def self.attrclass(name)
    @attrclasses ||= {}

    # We cache the value, since this method gets called such a huge number
    # of times (as in, hundreds of thousands in a given run).
    unless @attrclasses.include?(name)
      @attrclasses[name] = case self.attrtype(name)
      when :property; @validproperties[name]
      when :meta; @@metaparamhash[name]
      when :param; @paramhash[name]
      end
    end
    @attrclasses[name]
  end

  # Returns the attribute type (`:property`, `;param`, `:meta`).
  # @comment What type of parameter are we dealing with? Cache the results, because
  #   this method gets called so many times.
  # @return [Symbol] a symbol describing the type of attribute (`:property`, `;param`, `:meta`)
  #
  def self.attrtype(attr)
    @attrtypes ||= {}
    unless @attrtypes.include?(attr)
      @attrtypes[attr] = case
        when @validproperties.include?(attr); :property
        when @paramhash.include?(attr); :param
        when @@metaparamhash.include?(attr); :meta
        end
    end

    @attrtypes[attr]
  end

  # Provides iteration over meta-parameters.
  # @yieldparam p [Puppet::Parameter] each meta parameter
  # @return [void]
  #
  def self.eachmetaparam
    @@metaparams.each { |p| yield p.name }
  end

  # Creates a new `ensure` property with configured default values or with configuration by an optional block.
  # This method is a convenience method for creating a property `ensure` with default accepted values.
  # If no block is specified, the new `ensure` property will accept the default symbolic
  # values `:present`, and `:absent` - see {Puppet::Property::Ensure}.
  # If something else is wanted, pass a block and make calls to {Puppet::Property.newvalue} from this block
  # to define each possible value. If a block is passed, the defaults are not automatically added to the set of
  # valid values.
  #
  # @note This method will be automatically called without a block if the type implements the methods
  #   specified by {ensurable?}. It is recommended to always call this method and not rely on this automatic
  #   specification to clearly state that the type is ensurable.
  #
  # @overload ensurable()
  # @overload ensurable({|| ... })
  # @yield [ ] A block evaluated in scope of the new Parameter
  # @yieldreturn [void]
  # @return [void]
  # @dsl type
  # @api public
  #
  def self.ensurable(&block)
    if block_given?
      self.newproperty(:ensure, :parent => Puppet::Property::Ensure, &block)
    else
      self.newproperty(:ensure, :parent => Puppet::Property::Ensure) do
        self.defaultvalues
      end
    end
  end

  # Returns true if the type implements the default behavior expected by being _ensurable_ "by default".
  # A type is _ensurable_ by default if it responds to `:exists`, `:create`, and `:destroy`.
  # If a type implements these methods and have not already specified that it is _ensurable_, it will be
  # made so with the defaults specified in {ensurable}.
  # @return [Boolean] whether the type is _ensurable_ or not.
  #
  def self.ensurable?
    # If the class has all three of these methods defined, then it's
    # ensurable.
    [:exists?, :create, :destroy].all? { |method|
      self.public_method_defined?(method)
    }
  end

  # @comment These `apply_to` methods are horrible.  They should really be implemented
  #   as part of the usual system of constraints that apply to a type and
  #   provider pair, but were implemented as a separate shadow system.
  #
  # @comment We should rip them out in favour of a real constraint pattern around the
  #   target device - whatever that looks like - and not have this additional
  #   magic here. --daniel 2012-03-08
  #
  # Makes this type applicable to `:device`.
  # @return [Symbol] Returns `:device`
  # @api private
  #
  def self.apply_to_device
    @apply_to = :device
  end

  # Makes this type applicable to `:host`.
  # @return [Symbol] Returns `:host`
  # @api private
  #
  def self.apply_to_host
    @apply_to = :host
  end

  # Makes this type applicable to `:both` (i.e. `:host` and `:device`).
  # @return [Symbol] Returns `:both`
  # @api private
  #
  def self.apply_to_all
    @apply_to = :both
  end

  # Makes this type apply to `:host` if not already applied to something else.
  # @return [Symbol] a `:device`, `:host`, or `:both` enumeration
  # @api private
  def self.apply_to
    @apply_to ||= :host
  end

  # Returns true if this type is applicable to the given target.
  # @param target [Symbol] should be :device, :host or :target, if anything else, :host is enforced
  # @return [Boolean] true
  # @api private
  #
  def self.can_apply_to(target)
    [ target == :device ? :device : :host, :both ].include?(apply_to)
  end

  # Processes the options for a named parameter.
  # @param name [String] the name of a parameter
  # @param options [Hash] a hash of options
  # @option options [Boolean] :boolean if option set to true, an access method on the form _name_? is added for the param
  # @return [void]
  #
  def self.handle_param_options(name, options)
    # If it's a boolean parameter, create a method to test the value easily
    if options[:boolean]
      define_method(name.to_s + "?") do
        val = self[name]
        if val == :true or val == true
          return true
        end
      end
    end
  end

  # Is the given parameter a meta-parameter?
  # @return [Boolean] true if the given parameter is a meta-parameter.
  #
  def self.metaparam?(param)
    @@metaparamhash.include?(param.intern)
  end

  # Returns the meta-parameter class associated with the given meta-parameter name.
  # Accepts a `nil` name, and return nil.
  # @param name [String, nil] the name of a meta-parameter
  # @return [Class,nil] the class for the given meta-parameter, or `nil` if no such meta-parameter exists, (or if
  #   the given meta-parameter name is `nil`.
  #
  def self.metaparamclass(name)
    return nil if name.nil?
    @@metaparamhash[name.intern]
  end

  # Returns all meta-parameter names.
  # @return [Array<String>] all meta-parameter names
  #
  def self.metaparams
    @@metaparams.collect { |param| param.name }
  end

  # Returns the documentation for a given meta-parameter of this type.
  # @param metaparam [Puppet::Parameter] the meta-parameter to get documentation for.
  # @return [String] the documentation associated with the given meta-parameter, or nil of no such documentation
  #   exists.
  # @raise if the given metaparam is not a meta-parameter in this type
  #
  def self.metaparamdoc(metaparam)
    @@metaparamhash[metaparam].doc
  end

  # Creates a new meta-parameter.
  # This creates a new meta-parameter that is added to this and all inheriting types.
  # @param name [Symbol] the name of the parameter
  # @param options [Hash] a hash with options.
  # @option options [Class<inherits Puppet::Parameter>] :parent (Puppet::Parameter) the super class of this parameter
  # @option options [Hash{String => Object}] :attributes a hash that is applied to the generated class
  #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
  #   block is evaluated.
  # @option options [Boolean] :boolean (false) specifies if this is a boolean parameter
  # @option options [Boolean] :namevar  (false) specifies if this parameter is the namevar
  # @option options [Symbol, Array<Symbol>] :required_features  specifies required provider features by name
  # @return [Class<inherits Puppet::Parameter>] the created parameter
  # @yield [ ] a required block that is evaluated in the scope of the new meta-parameter
  # @api public
  # @dsl type
  # @todo Verify that this description is ok
  #
  def self.newmetaparam(name, options = {}, &block)
    @@metaparams ||= []
    @@metaparamhash ||= {}
    name = name.intern

    param = genclass(
      name,
      :parent => options[:parent] || Puppet::Parameter,
      :prefix => "MetaParam",
      :hash => @@metaparamhash,
      :array => @@metaparams,
      :attributes => options[:attributes],
      &block
    )

    # Grr.
    param.required_features = options[:required_features] if options[:required_features]

    handle_param_options(name, options)

    param.metaparam = true

    param
  end

  # Returns the list of parameters that comprise the composite key / "uniqueness key".
  # All parameters that return true from #isnamevar? or is named `:name` are included in the returned result.
  # @see uniqueness_key
  # @return [Array<Puppet::Parameter>] WARNING: this return type is uncertain
  def self.key_attribute_parameters
    @key_attribute_parameters ||= (
      @parameters.find_all { |param|
        param.isnamevar? or param.name == :name
      }
    )
  end

  # Returns cached {key_attribute_parameters} names.
  # Key attributes are properties and parameters that comprise a composite key
  # or "uniqueness key".
  # @return [Array<String>] cached key_attribute names
  #
  def self.key_attributes
    # This is a cache miss around 0.05 percent of the time. --daniel 2012-07-17
    @key_attributes_cache ||= key_attribute_parameters.collect { |p| p.name }
  end

  # Returns a mapping from the title string to setting of attribute value(s).
  # This default implementation provides a mapping of title to the one and only _namevar_ present
  # in the type's definition.
  # @note Advanced: some logic requires this mapping to be done differently, using a different
  #   validation/pattern, breaking up the title
  #   into several parts assigning each to an individual attribute, or even use a composite identity where
  #   all namevars are seen as part of the unique identity (such computation is done by the {#uniqueness} method.
  #   These advanced options are rarely used (only one of the built in puppet types use this, and then only
  #   a small part of the available functionality), and the support for these advanced mappings is not
  #   implemented in a straight forward way. For these reasons, this method has been marked as private).
  #
  # @raise [Puppet::DevError] if there is no title pattern and there are two or more key attributes
  # @return [Array<Array<Regexp, Array<Array <Symbol, Proc>>>>, nil] a structure with a regexp and the first key_attribute ???
  # @comment This wonderful piece of logic creates a structure used by Resource.parse_title which
  #   has the capability to assign parts of the title to one or more attributes; It looks like an implementation
  #   of a composite identity key (all parts of the key_attributes array are in the key). This can also
  #   be seen in the method uniqueness_key.
  #   The implementation in this method simply assigns the title to the one and only namevar (which is name
  #   or a variable marked as namevar).
  #   If there are multiple namevars (any in addition to :name?) then this method MUST be implemented
  #   as it raises an exception if there is more than 1. Note that in puppet, it is only File that uses this
  #   to create a different pattern for assigning to the :path attribute
  #   This requires further digging.
  #   The entire construct is somewhat strange, since resource checks if the method "title_patterns" is
  #   implemented (it seems it always is) - why take this more expensive regexp mathching route for all
  #   other types?
  # @api private
  #
  def self.title_patterns
    case key_attributes.length
    when 0; []
    when 1;
      [ [ /(.*)/m, [ [key_attributes.first] ] ] ]
    else
      raise Puppet::DevError,"you must specify title patterns when there are two or more key attributes"
    end
  end

  # Produces a resource's _uniqueness_key_ (or composite key).
  # This key is an array of all key attributes' values. Each distinct tuple must be unique for each resource type.
  # @see key_attributes
  # @return [Object] an object that is a _uniqueness_key_ for this object
  #
  def uniqueness_key
    self.class.key_attributes.sort_by { |attribute_name| attribute_name.to_s }.map{ |attribute_name| self[attribute_name] }
  end

  # Creates a new parameter.
  # @param name [Symbol] the name of the parameter
  # @param options [Hash] a hash with options.
  # @option options [Class<inherits Puppet::Parameter>] :parent (Puppet::Parameter) the super class of this parameter
  # @option options [Hash{String => Object}] :attributes a hash that is applied to the generated class
  #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
  #   block is evaluated.
  # @option options [Boolean] :boolean (false) specifies if this is a boolean parameter
  # @option options [Boolean] :namevar  (false) specifies if this parameter is the namevar
  # @option options [Symbol, Array<Symbol>] :required_features  specifies required provider features by name
  # @return [Class<inherits Puppet::Parameter>] the created parameter
  # @yield [ ] a required block that is evaluated in the scope of the new parameter
  # @api public
  # @dsl type
  #
  def self.newparam(name, options = {}, &block)
    options[:attributes] ||= {}

    param = genclass(
      name,
      :parent     => options[:parent] || Puppet::Parameter,
      :attributes => options[:attributes],
      :block      => block,
      :prefix     => "Parameter",
      :array      => @parameters,
      :hash       => @paramhash
    )

    handle_param_options(name, options)

    # Grr.
    param.required_features = options[:required_features] if options[:required_features]

    param.isnamevar if options[:namevar]

    param
  end

  # Creates a new property.
  # @param name [Symbol] the name of the property
  # @param options [Hash] a hash with options.
  # @option options [Symbol] :array_matching (:first) specifies how the current state is matched against
  #   the wanted state. Use `:first` if the property is single valued, and (`:all`) otherwise.
  # @option options [Class<inherits Puppet::Property>] :parent (Puppet::Property) the super class of this property
  # @option options [Hash{String => Object}] :attributes a hash that is applied to the generated class
  #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
  #   block is evaluated.
  # @option options [Boolean] :boolean (false) specifies if this is a boolean parameter
  # @option options [Symbol] :retrieve the method to call on the provider (or `parent` if `provider` is not set)
  #   to retrieve the current value of this property.
  # @option options [Symbol, Array<Symbol>] :required_features  specifies required provider features by name
  # @return [Class<inherits Puppet::Property>] the created property
  # @yield [ ] a required block that is evaluated in the scope of the new property
  # @api public
  # @dsl type
  #
  def self.newproperty(name, options = {}, &block)
    name = name.intern

    # This is here for types that might still have the old method of defining
    # a parent class.
    unless options.is_a? Hash
      raise Puppet::DevError,
        "Options must be a hash, not #{options.inspect}"
    end

    raise Puppet::DevError, "Class #{self.name} already has a property named #{name}" if @validproperties.include?(name)

    if parent = options[:parent]
      options.delete(:parent)
    else
      parent = Puppet::Property
    end

    # We have to create our own, new block here because we want to define
    # an initial :retrieve method, if told to, and then eval the passed
    # block if available.
    prop = genclass(name, :parent => parent, :hash => @validproperties, :attributes => options) do
      # If they've passed a retrieve method, then override the retrieve
      # method on the class.
      if options[:retrieve]
        define_method(:retrieve) do
          provider.send(options[:retrieve])
        end
      end

      class_eval(&block) if block
    end

    # If it's the 'ensure' property, always put it first.
    if name == :ensure
      @properties.unshift prop
    else
      @properties << prop
    end

    prop
  end

  def self.paramdoc(param)
    @paramhash[param].doc
  end

  # @return [Array<String>] Returns the parameter names
  def self.parameters
    return [] unless defined?(@parameters)
    @parameters.collect { |klass| klass.name }
  end

  # @return [Puppet::Parameter] Returns the parameter class associated with the given parameter name.
  def self.paramclass(name)
    @paramhash[name]
  end

  # @return [Puppet::Property] Returns the property class ??? associated with the given property name
  def self.propertybyname(name)
    @validproperties[name]
  end

  # Returns whether or not the given name is the name of a property, parameter or meta-parameter
  # @return [Boolean] true if the given attribute name is the name of an existing property, parameter or meta-parameter
  #
  def self.validattr?(name)
    name = name.intern
    return true if name == :name
    @validattrs ||= {}

    unless @validattrs.include?(name)
      @validattrs[name] = !!(self.validproperty?(name) or self.validparameter?(name) or self.metaparam?(name))
    end

    @validattrs[name]
  end

  # @return [Boolean] Returns true if the given name is the name of an existing property
  def self.validproperty?(name)
    name = name.intern
    @validproperties.include?(name) && @validproperties[name]
  end

  # @return [Array<Symbol>, {}] Returns a list of valid property names, or an empty hash if there are none.
  # @todo An empty hash is returned if there are no defined parameters (not an empty array). This looks like
  #   a bug.
  #
  def self.validproperties
    return {} unless defined?(@parameters)

    @validproperties.keys
  end

  # @return [Boolean] Returns true if the given name is the name of an existing parameter
  def self.validparameter?(name)
    raise Puppet::DevError, "Class #{self} has not defined parameters" unless defined?(@parameters)
    !!(@paramhash.include?(name) or @@metaparamhash.include?(name))
  end

  # (see validattr?)
  # @note see comment in code - how should this be documented? Are some of the other query methods deprecated?
  #   (or should be).
  # @comment This is a forward-compatibility method - it's the validity interface we'll use in Puppet::Resource.
  def self.valid_parameter?(name)
    validattr?(name)
  end

  # @return [Boolean] Returns true if the wanted state of the resource is that it should be absent (i.e. to be deleted).
  def deleting?
    obj = @parameters[:ensure] and obj.should == :absent
  end

  # Creates a new property value holder for the resource if it is valid and does not already exist
  # @return [Boolean] true if a new parameter was added, false otherwise
  def add_property_parameter(prop_name)
    if self.class.validproperty?(prop_name) && !@parameters[prop_name]
      self.newattr(prop_name)
      return true
    end
    false
  end

  # @return [Symbol, Boolean] Returns the name of the namevar if there is only one or false otherwise.
  # @comment This is really convoluted and part of the support for multiple namevars (?).
  #   If there is only one namevar, the produced value is naturally this namevar, but if there are several?
  #   The logic caches the name of the namevar if it is a single name, but otherwise always
  #   calls key_attributes, and then caches the first if there was only one, otherwise it returns
  #   false and caches this (which is then subsequently returned as a cache hit).
  #
  def name_var
    return @name_var_cache unless @name_var_cache.nil?
    key_attributes = self.class.key_attributes
    @name_var_cache = (key_attributes.length == 1) && key_attributes.first
  end

  # Gets the 'should' (wanted state) value of a parameter or property by name.
  # To explicitly get the 'is' (current state) value use `o.is(:name)`, and to explicitly get the 'should' value
  # use `o.should(:name)`
  # @param name [String] the name of the attribute to obtain the 'should' value for.
  # @return [Object] 'should'/wanted value of the given attribute
  def [](name)
    name = name.intern
    fail("Invalid parameter #{name}(#{name.inspect})") unless self.class.validattr?(name)

    if name == :name && nv = name_var
      name = nv
    end

    if obj = @parameters[name]
      # Note that if this is a property, then the value is the "should" value,
      # not the current value.
      obj.value
    else
      return nil
    end
  end

  # Sets the 'should' (wanted state) value of a property, or the value of a parameter.
  # @return
  # @raise [Puppet::Error] if the setting of the value fails, or if the given name is nil.
  # @raise [Puppet::ResourceError] when the parameter validation raises Puppet::Error or
  #   ArgumentError
  def []=(name,value)
    name = name.intern

    fail("no parameter named '#{name}'") unless self.class.validattr?(name)

    if name == :name && nv = name_var
      name = nv
    end
    raise Puppet::Error.new("Got nil value for #{name}") if value.nil?

    property = self.newattr(name)

    if property
      begin
        # make sure the parameter doesn't have any errors
        property.value = value
      rescue Puppet::Error, ArgumentError => detail
        error = Puppet::ResourceError.new("Parameter #{name} failed on #{ref}: #{detail}")
        adderrorcontext(error, detail)
        raise error
      end
    end

    nil
  end

  # Removes an attribute from the object; useful in testing or in cleanup
  # when an error has been encountered
  # @todo Don't know what the attr is (name or Property/Parameter?). Guessing it is a String name...
  # @todo Is it possible to delete a meta-parameter?
  # @todo What does delete mean? Is it deleted from the type or is its value state 'is'/'should' deleted?
  # @param attr [String] the attribute to delete from this object. WHAT IS THE TYPE?
  # @raise [Puppet::DecError] when an attempt is made to delete an attribute that does not exists.
  #
  def delete(attr)
    attr = attr.intern
    if @parameters.has_key?(attr)
      @parameters.delete(attr)
    else
      raise Puppet::DevError.new("Undefined attribute '#{attr}' in #{self}")
    end
  end

  # Iterates over the properties that were set on this resource.
  # @yieldparam property [Puppet::Property] each property
  # @return [void]
  def eachproperty
    # properties is a private method
    properties.each { |property|
      yield property
    }
  end

  # Return the parameters, metaparams, and properties that have a value or were set by a default. Properties are
  # included since they are a subclass of parameter.
  # @return [Array<Puppet::Parameter>] Array of parameter objects ( or subclass thereof )
  def parameters_with_value
    self.class.allattrs.collect { |attr| parameter(attr) }.compact
  end

  # Iterates over all parameters with value currently set.
  # @yieldparam parameter [Puppet::Parameter] or a subclass thereof
  # @return [void]
  def eachparameter
    parameters_with_value.each { |parameter| yield parameter }
  end

  # Creates a transaction event.
  # Called by Transaction or by a property.
  # Merges the given options with the options `:resource`, `:file`, `:line`, and `:tags`, initialized from
  # values in this object. For possible options to pass (if any ????) see {Puppet::Transaction::Event}.
  # @todo Needs a better explanation "Why should I care who is calling this method?", What do I need to know
  #   about events and how they work? Where can I read about them?
  # @param options [Hash] options merged with a fixed set of options defined by this method, passed on to {Puppet::Transaction::Event}.
  # @return [Puppet::Transaction::Event] the created event
  def event(options = {})
    Puppet::Transaction::Event.new({:resource => self, :file => file, :line => line, :tags => tags}.merge(options))
  end

  # @return [Object, nil] Returns the 'should' (wanted state) value for a specified property, or nil if the
  #   given attribute name is not a property (i.e. if it is a parameter, meta-parameter, or does not exist).
  def should(name)
    name = name.intern
    (prop = @parameters[name] and prop.is_a?(Puppet::Property)) ? prop.should : nil
  end

  # Registers an attribute to this resource type instance.
  # Requires either the attribute name or class as its argument.
  # This is a noop if the named property/parameter is not supported
  # by this resource. Otherwise, an attribute instance is created
  # and kept in this resource's parameters hash.
  # @overload newattr(name)
  #   @param name [Symbol] symbolic name of the attribute
  # @overload newattr(klass)
  #   @param klass [Class] a class supported as an attribute class, i.e. a subclass of
  #     Parameter or Property
  # @return [Object] An instance of the named Parameter or Property class associated
  #   to this resource type instance, or nil if the attribute is not supported
  #
  def newattr(name)
    if name.is_a?(Class)
      klass = name
      name = klass.name
    end

    unless klass = self.class.attrclass(name)
      raise Puppet::Error, "Resource type #{self.class.name} does not support parameter #{name}"
    end

    if provider and ! provider.class.supports_parameter?(klass)
      missing = klass.required_features.find_all { |f| ! provider.class.feature?(f) }
      debug "Provider %s does not support features %s; not managing attribute %s" % [provider.class.name, missing.join(", "), name]
      return nil
    end

    return @parameters[name] if @parameters.include?(name)

    @parameters[name] = klass.new(:resource => self)
  end

  # Returns a string representation of the resource's containment path in
  # the catalog.
  # @return [String]
  def path
    @path ||= '/' + pathbuilder.join('/')
  end

  # Returns the value of this object's parameter given by name
  # @param name [String] the name of the parameter
  # @return [Object] the value
  def parameter(name)
    @parameters[name.to_sym]
  end

  # Returns a shallow copy of this object's hash of attributes by name.
  # Note that his not only comprises parameters, but also properties and metaparameters.
  # Changes to the contained parameters will have an effect on the parameters of this type, but changes to
  # the returned hash does not.
  # @return [Hash{String => Object}] a new hash being a shallow copy of the parameters map name to parameter
  def parameters
    @parameters.dup
  end

  # @return [Boolean] Returns whether the attribute given by name has been added
  #   to this resource or not.
  def propertydefined?(name)
    name = name.intern unless name.is_a? Symbol
    @parameters.include?(name)
  end

  # Returns a {Puppet::Property} instance by name.
  # To return the value, use 'resource[param]'
  # @todo LAK:NOTE(20081028) Since the 'parameter' method is now a superset of this method,
  #   this one should probably go away at some point. - Does this mean it should be deprecated ?
  # @return [Puppet::Property] the property with the given name, or nil if not a property or does not exist.
  def property(name)
    (obj = @parameters[name.intern] and obj.is_a?(Puppet::Property)) ? obj : nil
  end

  # @todo comment says "For any parameters or properties that have defaults and have not yet been
  #   set, set them now.  This method can be handed a list of attributes,
  #   and if so it will only set defaults for those attributes."
  # @todo Needs a better explanation, and investigation about the claim an array can be passed (it is passed
  #   to self.class.attrclass to produce a class on which a check is made if it has a method class :default (does
  #   not seem to support an array...
  # @return [void]
  #
  def set_default(attr)
    return unless klass = self.class.attrclass(attr)
    return unless klass.method_defined?(:default)
    return if @parameters.include?(klass.name)

    return unless parameter = newattr(klass.name)

    if value = parameter.default and ! value.nil?
      parameter.value = value
    else
      @parameters.delete(parameter.name)
    end
  end

  # @todo the comment says: "Convert our object to a hash.  This just includes properties."
  # @todo this is confused, again it is the @parameters instance variable that is consulted, and
  #   each value is copied - does it contain "properties" and "parameters" or both? Does it contain
  #   meta-parameters?
  #
  # @return [Hash{ ??? => ??? }] a hash of WHAT?. The hash is a shallow copy, any changes to the
  #  objects returned in this hash will be reflected in the original resource having these attributes.
  #
  def to_hash
    rethash = {}

    @parameters.each do |name, obj|
      rethash[name] = obj.value
    end

    rethash
  end

  # @return [String] the name of this object's class
  # @todo Would that be "file" for the "File" resource type? of "File" or something else?
  #
  def type
    self.class.name
  end

  # @todo Comment says "Return a specific value for an attribute.", as opposed to what "An unspecific value"???
  # @todo is this the 'is' or the 'should' value?
  # @todo why is the return restricted to things that respond to :value? (Only non structural basic data types
  #   supported?
  #
  # @return [Object, nil] the value of the attribute having the given name, or nil if the given name is not
  #   an attribute, or the referenced attribute does not respond to `:value`.
  def value(name)
    name = name.intern

    (obj = @parameters[name] and obj.respond_to?(:value)) ? obj.value : nil
  end

  # @todo What is this used for? Needs a better explanation.
  # @return [???] the version of the catalog or 0 if there is no catalog.
  def version
    return 0 unless catalog
    catalog.version
  end

  # @return [Array<Puppet::Property>] Returns all of the property objects, in the order specified in the
  #   class.
  # @todo "what does the 'order specified in the class' mean? The order the properties where added in the
  #   ruby file adding a new type with new properties?
  #
  def properties
    self.class.properties.collect { |prop| @parameters[prop.name] }.compact
  end

  # Returns true if the type's notion of name is the identity of a resource.
  # See the overview of this class for a longer explanation of the concept _isomorphism_.
  # Defaults to true.
  #
  # @return [Boolean] true, if this type's name is isomorphic with the object
  def self.isomorphic?
    if defined?(@isomorphic)
      return @isomorphic
    else
      return true
    end
  end

  # @todo check that this gets documentation (it is at the class level as well as instance).
  # (see isomorphic?)
  def isomorphic?
    self.class.isomorphic?
  end

  # Returns true if the instance is a managed instance.
  # A 'yes' here means that the instance was created from the language, vs. being created
  # in order resolve other questions, such as finding a package in a list.
  # @note An object that is managed always stays managed, but an object that is not managed
  #   may become managed later in its lifecycle.
  # @return [Boolean] true if the object is managed
  def managed?
    # Once an object is managed, it always stays managed; but an object
    # that is listed as unmanaged might become managed later in the process,
    # so we have to check that every time
    if @managed
      return @managed
    else
      @managed = false
      properties.each { |property|
        s = property.should
        if s and ! property.class.unmanaged
          @managed = true
          break
        end
      }
      return @managed
    end
  end

  ###############################
  # Code related to the container behaviour.

  # Returns true if the search should be done in depth-first order.
  # This implementation always returns false.
  # @todo What is this used for?
  #
  # @return [Boolean] true if the search should be done in depth first order.
  #
  def depthfirst?
    false
  end

  # Removes this object (FROM WHERE?)
  # @todo removes if from where?
  # @return [void]
  def remove()
    # This is hackish (mmm, cut and paste), but it works for now, and it's
    # better than warnings.
    @parameters.each do |name, obj|
      obj.remove
    end
    @parameters.clear

    @parent = nil

    # Remove the reference to the provider.
    if self.provider
      @provider.clear
      @provider = nil
    end
  end

  ###############################
  # Code related to evaluating the resources.

  # Returns the ancestors - WHAT?
  # This implementation always returns an empty list.
  # @todo WHAT IS THIS ?
  # @return [Array<???>] returns a list of ancestors.
  def ancestors
    []
  end

  # Lifecycle method for a resource. This is called during graph creation.
  # It should perform any consistency checking of the catalog and raise a
  # Puppet::Error if the transaction should be aborted.
  #
  # It differs from the validate method, since it is called later during
  # initialization and can rely on self.catalog to have references to all
  # resources that comprise the catalog.
  #
  # @see Puppet::Transaction#add_vertex
  # @raise [Puppet::Error] If the pre-run check failed.
  # @return [void]
  # @abstract a resource type may implement this method to perform
  #   validation checks that can query the complete catalog
  def pre_run_check
  end

  # Flushes the provider if supported by the provider, else no action.
  # This is called by the transaction.
  # @todo What does Flushing the provider mean? Why is it interesting to know that this is
  #   called by the transaction? (It is not explained anywhere what a transaction is).
  #
  # @return [???, nil] WHAT DOES IT RETURN? GUESS IS VOID
  def flush
    self.provider.flush if self.provider and self.provider.respond_to?(:flush)
  end

  # Returns true if all contained objects are in sync.
  # @todo "contained in what?" in the given "in" parameter?
  #
  # @todo deal with the comment _"FIXME I don't think this is used on the type instances any more,
  #   it's really only used for testing"_
  # @return [Boolean] true if in sync, false otherwise.
  #
  def insync?(is)
    insync = true

    if property = @parameters[:ensure]
      unless is.include? property
        raise Puppet::DevError,
          "The is value is not in the is array for '#{property.name}'"
      end
      ensureis = is[property]
      if property.safe_insync?(ensureis) and property.should == :absent
        return true
      end
    end

    properties.each { |prop|
      unless is.include? prop
        raise Puppet::DevError,
          "The is value is not in the is array for '#{prop.name}'"
      end

      propis = is[prop]
      unless prop.safe_insync?(propis)
        prop.debug("Not in sync: #{propis.inspect} vs #{prop.should.inspect}")
        insync = false
      #else
      #    property.debug("In sync")
      end
    }

    #self.debug("#{self} sync status is #{insync}")
    insync
  end

  # Says if the ensure property should be retrieved if the resource is ensurable
  # Defaults to true. Some resource type classes can override it
  def self.needs_ensure_retrieved
    true
  end

  # Retrieves the current value of all contained properties.
  # Parameters and meta-parameters are not included in the result.
  # @todo As opposed to all non contained properties? How is this different than any of the other
  #   methods that also "gets" properties/parameters/etc. ?
  # @return [Puppet::Resource] array of all property values (mix of types)
  # @raise [fail???] if there is a provider and it is not suitable for the host this is evaluated for.
  def retrieve
    fail "Provider #{provider.class.name} is not functional on this host" if self.provider.is_a?(Puppet::Provider) and ! provider.class.suitable?

    result = Puppet::Resource.new(self.class, title)

    # Provide the name, so we know we'll always refer to a real thing
    result[:name] = self[:name] unless self[:name] == title

    if ensure_prop = property(:ensure) or (self.class.needs_ensure_retrieved and self.class.validattr?(:ensure) and ensure_prop = newattr(:ensure))
      result[:ensure] = ensure_state = ensure_prop.retrieve
    else
      ensure_state = nil
    end

    properties.each do |property|
      next if property.name == :ensure
      if ensure_state == :absent
        result[property] = :absent
      else
        result[property] = property.retrieve
      end
    end

    result
  end

  # Retrieve the current state of the system as a Puppet::Resource. For
  # the base Puppet::Type this does the same thing as #retrieve, but
  # specific types are free to implement #retrieve as returning a hash,
  # and this will call #retrieve and convert the hash to a resource.
  # This is used when determining when syncing a resource.
  #
  # @return [Puppet::Resource] A resource representing the current state
  #   of the system.
  #
  # @api private
  def retrieve_resource
    resource = retrieve
    resource = Resource.new(self.class, title, :parameters => resource) if resource.is_a? Hash
    resource
  end

  # Given the hash of current properties, should this resource be treated as if it
  # currently exists on the system. May need to be overridden by types that offer up
  # more than just :absent and :present.
  def present?(current_values)
    current_values[:ensure] != :absent
  end

  # Returns a hash of the current properties and their values.
  # If a resource is absent, its value is the symbol `:absent`
  # @return [Hash{Puppet::Property => Object}] mapping of property instance to its value
  #
  def currentpropvalues
    # It's important to use the 'properties' method here, as it follows the order
    # in which they're defined in the class.  It also guarantees that 'ensure'
    # is the first property, which is important for skipping 'retrieve' on
    # all the properties if the resource is absent.
    ensure_state = false
    return properties.inject({}) do | prophash, property|
      if property.name == :ensure
        ensure_state = property.retrieve
        prophash[property] = ensure_state
      else
        if ensure_state == :absent
          prophash[property] = :absent
        else
          prophash[property] = property.retrieve
        end
      end
      prophash
    end
  end

  # Returns the `noop` run mode status of this.
  # @return [Boolean] true if running in noop mode.
  def noop?
    # If we're not a host_config, we're almost certainly part of
    # Settings, and we want to ignore 'noop'
    return false if catalog and ! catalog.host_config?

    if defined?(@noop)
      @noop
    else
      Puppet[:noop]
    end
  end

  # (see #noop?)
  def noop
    noop?
  end

  # Retrieves all known instances.
  # @todo Retrieves them from where? Known to whom?
  # Either requires providers or must be overridden.
  # @raise [Puppet::DevError] when there are no providers and the implementation has not overridden this method.
  def self.instances
    raise Puppet::DevError, "#{self.name} has no providers and has not overridden 'instances'" if provider_hash.empty?

    # Put the default provider first, then the rest of the suitable providers.
    provider_instances = {}
    providers_by_source.collect do |provider|
      self.properties.find_all do |property|
        provider.supports_parameter?(property)
      end.collect do |property|
        property.name
      end

      provider.instances.collect do |instance|
        # We always want to use the "first" provider instance we find, unless the resource
        # is already managed and has a different provider set
        if other = provider_instances[instance.name]
          Puppet.debug "%s %s found in both %s and %s; skipping the %s version" %
            [self.name.to_s.capitalize, instance.name, other.class.name, instance.class.name, instance.class.name]
          next
        end
        provider_instances[instance.name] = instance

        result = new(:name => instance.name, :provider => instance)
        properties.each { |name| result.newattr(name) }
        result
      end
    end.flatten.compact
  end

  # Returns a list of one suitable provider per source, with the default provider first.
  # @todo Needs better explanation; what does "source" mean in this context?
  # @return [Array<Puppet::Provider>] list of providers
  #
  def self.providers_by_source
    # Put the default provider first (can be nil), then the rest of the suitable providers.
    sources = []
    [defaultprovider, suitableprovider].flatten.uniq.collect do |provider|
      next if provider.nil?
      next if sources.include?(provider.source)

      sources << provider.source
      provider
    end.compact
  end

  # Converts a simple hash into a Resource instance.
  # @todo as opposed to a complex hash? Other raised exceptions?
  # @param [Hash{Symbol, String => Object}] hash resource attribute to value map to initialize the created resource from
  # @return [Puppet::Resource] the resource created from the hash
  # @raise [Puppet::Error] if a title is missing in the given hash
  def self.hash2resource(hash)
    hash = hash.inject({}) { |result, ary| result[ary[0].to_sym] = ary[1]; result }

    title = hash.delete(:title)
    title ||= hash[:name]
    title ||= hash[key_attributes.first] if key_attributes.length == 1

    raise Puppet::Error, "Title or name must be provided" unless title

    # Now create our resource.
    resource = Puppet::Resource.new(self, title)
    resource.catalog = hash.delete(:catalog)

    hash.each do |param, value|
      resource[param] = value
    end
    resource
  end


  # Returns an array of strings representing the containment hierarchy
  # (types/classes) that make up the path to the resource from the root
  # of the catalog.  This is mostly used for logging purposes.
  #
  # @api private
  def pathbuilder
    if p = parent
      [p.pathbuilder, self.ref].flatten
    else
      [self.ref]
    end
  end

  ###############################
  # Add all of the meta-parameters.
  newmetaparam(:noop) do
    desc "Whether to apply this resource in noop mode.

      When applying a resource in noop mode, Puppet will check whether it is in sync,
      like it does when running normally. However, if a resource attribute is not in
      the desired state (as declared in the catalog), Puppet will take no
      action, and will instead report the changes it _would_ have made. These
      simulated changes will appear in the report sent to the puppet master, or
      be shown on the console if running puppet agent or puppet apply in the
      foreground. The simulated changes will not send refresh events to any
      subscribing or notified resources, although Puppet will log that a refresh
      event _would_ have been sent.

      **Important note:**
      [The `noop` setting](https://docs.puppetlabs.com/puppet/latest/reference/configuration.html#noop)
      allows you to globally enable or disable noop mode, but it will _not_ override
      the `noop` metaparameter on individual resources. That is, the value of the
      global `noop` setting will _only_ affect resources that do not have an explicit
      value set for their `noop` attribute."

    newvalues(:true, :false)
    munge do |value|
      case value
      when true, :true, "true"; @resource.noop = true
      when false, :false, "false"; @resource.noop = false
      end
    end
  end

  newmetaparam(:schedule) do
    desc "A schedule to govern when Puppet is allowed to manage this resource.
      The value of this metaparameter must be the `name` of a `schedule`
      resource. This means you must declare a schedule resource, then
      refer to it by name; see
      [the docs for the `schedule` type](https://docs.puppetlabs.com/puppet/latest/reference/type.html#schedule)
      for more info.

          schedule { 'everyday':
            period => daily,
            range  => \"2-4\"
          }

          exec { \"/usr/bin/apt-get update\":
            schedule => 'everyday'
          }

      Note that you can declare the schedule resource anywhere in your
      manifests, as long as it ends up in the final compiled catalog."
  end

  newmetaparam(:audit) do
    desc "Marks a subset of this resource's unmanaged attributes for auditing. Accepts an
      attribute name, an array of attribute names, or `all`.

      Auditing a resource attribute has two effects: First, whenever a catalog
      is applied with puppet apply or puppet agent, Puppet will check whether
      that attribute of the resource has been modified, comparing its current
      value to the previous run; any change will be logged alongside any actions
      performed by Puppet while applying the catalog.

      Secondly, marking a resource attribute for auditing will include that
      attribute in inspection reports generated by puppet inspect; see the
      puppet inspect documentation for more details.

      Managed attributes for a resource can also be audited, but note that
      changes made by Puppet will be logged as additional modifications. (I.e.
      if a user manually edits a file whose contents are audited and managed,
      puppet agent's next two runs will both log an audit notice: the first run
      will log the user's edit and then revert the file to the desired state,
      and the second run will log the edit made by Puppet.)"

    validate do |list|
      list = Array(list).collect {|p| p.to_sym}
      unless list == [:all]
        list.each do |param|
          next if @resource.class.validattr?(param)
          fail "Cannot audit #{param}: not a valid attribute for #{resource}"
        end
      end
    end

    munge do |args|
      properties_to_audit(args).each do |param|
        next unless resource.class.validproperty?(param)
        resource.newattr(param)
      end
    end

    def all_properties
      resource.class.properties.find_all do |property|
        resource.provider.nil? or resource.provider.class.supports_parameter?(property)
      end.collect do |property|
        property.name
      end
    end

    def properties_to_audit(list)
      if !list.kind_of?(Array) && list.to_sym == :all
        list = all_properties
      else
        list = Array(list).collect { |p| p.to_sym }
      end
    end
  end

  newmetaparam(:loglevel) do
    desc "Sets the level that information will be logged.
      The log levels have the biggest impact when logs are sent to
      syslog (which is currently the default).

      The order of the log levels, in decreasing priority, is:

      * `crit`
      * `emerg`
      * `alert`
      * `err`
      * `warning`
      * `notice`
      * `info` / `verbose`
      * `debug`
      "
    defaultto :notice

    newvalues(*Puppet::Util::Log.levels)
    newvalues(:verbose)

    munge do |loglevel|
      val = super(loglevel)
      if val == :verbose
        val = :info
      end
      val
    end
  end

  newmetaparam(:alias) do
    desc %q{Creates an alias for the resource.  Puppet uses this internally when you
      provide a symbolic title and an explicit namevar value:

          file { 'sshdconfig':
            path => $operatingsystem ? {
              solaris => '/usr/local/etc/ssh/sshd_config',
              default => '/etc/ssh/sshd_config',
            },
            source => '...'
          }

          service { 'sshd':
            subscribe => File['sshdconfig'],
          }

      When you use this feature, the parser sets `sshdconfig` as the title,
      and the library sets that as an alias for the file so the dependency
      lookup in `Service['sshd']` works.  You can use this metaparameter yourself,
      but note that aliases generally only work for creating relationships; anything
      else that refers to an existing resource (such as amending or overriding
      resource attributes in an inherited class) must use the resource's exact
      title. For example, the following code will not work:

          file { '/etc/ssh/sshd_config':
            owner => root,
            group => root,
            alias => 'sshdconfig',
          }

          File['sshdconfig'] {
            mode => '0644',
          }

      There's no way here for the Puppet parser to know that these two stanzas
      should be affecting the same file.

      }

    munge do |aliases|
      aliases = [aliases] unless aliases.is_a?(Array)

      raise(ArgumentError, "Cannot add aliases without a catalog") unless @resource.catalog

      aliases.each do |other|
        if obj = @resource.catalog.resource(@resource.class.name, other)
          unless obj.object_id == @resource.object_id
            self.fail("#{@resource.title} can not create alias #{other}: object already exists")
          end
          next
        end

        # Newschool, add it to the catalog.
        @resource.catalog.alias(@resource, other)
      end
    end
  end

  newmetaparam(:tag) do
    desc "Add the specified tags to the associated resource.  While all resources
      are automatically tagged with as much information as possible
      (e.g., each class and definition containing the resource), it can
      be useful to add your own tags to a given resource.

      Multiple tags can be specified as an array:

          file {'/etc/hosts':
            ensure => file,
            source => 'puppet:///modules/site/hosts',
            mode   => '0644',
            tag    => ['bootstrap', 'minimumrun', 'mediumrun'],
          }

      Tags are useful for things like applying a subset of a host's configuration
      with [the `tags` setting](/puppet/latest/reference/configuration.html#tags)
      (e.g. `puppet agent --test --tags bootstrap`)."

    munge do |tags|
      tags = [tags] unless tags.is_a? Array

      tags.each do |tag|
        @resource.tag(tag)
      end
    end
  end

  # RelationshipMetaparam is an implementation supporting the meta-parameters `:require`, `:subscribe`,
  # `:notify`, and `:before`.
  #
  #
  class RelationshipMetaparam < Puppet::Parameter
    class << self
      attr_accessor :direction, :events, :callback, :subclasses
    end

    @subclasses = []

    def self.inherited(sub)
      @subclasses << sub
    end

    # @return [Array<Puppet::Resource>] turns attribute value(s) into list of resources
    def munge(references)
      references = [references] unless references.is_a?(Array)
      references.collect do |ref|
        if ref.is_a?(Puppet::Resource)
          ref
        else
          Puppet::Resource.new(ref)
        end
      end
    end

    # Checks each reference to assert that what it references exists in the catalog.
    #
    # @raise [???fail] if the referenced resource can not be found
    # @return [void]
    def validate_relationship
      @value.each do |ref|
        unless @resource.catalog.resource(ref.to_s)
          description = self.class.direction == :in ? "dependency" : "dependent"
          fail ResourceError, "Could not find #{description} #{ref} for #{resource.ref}"
        end
      end
    end

    # Creates edges for all relationships.
    # The `:in` relationships are specified by the event-receivers, and `:out`
    # relationships are specified by the event generator.
    # @todo references to "event-receivers" and "event generator" means in this context - are those just
    #   the resources at the two ends of the relationship?
    # This way 'source' and 'target' are consistent terms in both edges
    # and events, i.e. an event targets edges whose source matches
    # the event's source. The direction of the relationship determines
    # which resource is applied first and which resource is considered
    # to be the event generator.
    # @return [Array<Puppet::Relationship>]
    # @raise [???fail] when a reference can not be resolved
    #
    def to_edges
      @value.collect do |reference|
        reference.catalog = resource.catalog

        # Either of the two retrieval attempts could have returned
        # nil.
        unless related_resource = reference.resolve
          self.fail "Could not retrieve dependency '#{reference}' of #{@resource.ref}"
        end

        # Are we requiring them, or vice versa?  See the method docs
        # for further info on this.
        if self.class.direction == :in
          source = related_resource
          target = @resource
        else
          source = @resource
          target = related_resource
        end

        if method = self.class.callback
          subargs = {
            :event => self.class.events,
            :callback => method
          }
          self.debug { "subscribes to #{related_resource.ref}" }
        else
          # If there's no callback, there's no point in even adding
          # a label.
          subargs = nil
          self.debug { "subscribes to #{related_resource.ref}" }
        end

        Puppet::Relationship.new(source, target, subargs)
      end
    end
  end

  # @todo document this, have no clue what this does... it returns "RelationshipMetaparam.subclasses"
  #
  def self.relationship_params
    RelationshipMetaparam.subclasses
  end


  # Note that the order in which the relationships params is defined
  # matters.  The labeled params (notify and subscribe) must be later,
  # so that if both params are used, those ones win.  It's a hackish
  # solution, but it works.

  newmetaparam(:require, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :NONE}) do
    desc "One or more resources that this resource depends on, expressed as
      [resource references](https://docs.puppetlabs.com/puppet/latest/reference/lang_data_resource_reference.html).
      Multiple resources can be specified as an array of references. When this
      attribute is present:

      * The required resource(s) will be applied **before** this resource.

      This is one of the four relationship metaparameters, along with
      `before`, `notify`, and `subscribe`. For more context, including the
      alternate chaining arrow (`->` and `~>`) syntax, see
      [the language page on relationships](https://docs.puppetlabs.com/puppet/latest/reference/lang_relationships.html)."
  end

  newmetaparam(:subscribe, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :ALL_EVENTS, :callback => :refresh}) do
    desc "One or more resources that this resource depends on, expressed as
      [resource references](https://docs.puppetlabs.com/puppet/latest/reference/lang_data_resource_reference.html).
      Multiple resources can be specified as an array of references. When this
      attribute is present:

      * The subscribed resource(s) will be applied _before_ this resource.
      * If Puppet makes changes to any of the subscribed resources, it will cause
        this resource to _refresh._ (Refresh behavior varies by resource
        type: services will restart, mounts will unmount and re-mount, etc. Not
        all types can refresh.)

      This is one of the four relationship metaparameters, along with
      `before`, `require`, and `notify`. For more context, including the
      alternate chaining arrow (`->` and `~>`) syntax, see
      [the language page on relationships](https://docs.puppetlabs.com/puppet/latest/reference/lang_relationships.html)."
  end

  newmetaparam(:before, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :NONE}) do
    desc "One or more resources that depend on this resource, expressed as
      [resource references](https://docs.puppetlabs.com/puppet/latest/reference/lang_data_resource_reference.html).
      Multiple resources can be specified as an array of references. When this
      attribute is present:

      * This resource will be applied _before_ the dependent resource(s).

      This is one of the four relationship metaparameters, along with
      `require`, `notify`, and `subscribe`. For more context, including the
      alternate chaining arrow (`->` and `~>`) syntax, see
      [the language page on relationships](https://docs.puppetlabs.com/puppet/latest/reference/lang_relationships.html)."
  end

  newmetaparam(:notify, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :ALL_EVENTS, :callback => :refresh}) do
    desc "One or more resources that depend on this resource, expressed as
      [resource references](https://docs.puppetlabs.com/puppet/latest/reference/lang_data_resource_reference.html).
      Multiple resources can be specified as an array of references. When this
      attribute is present:

      * This resource will be applied _before_ the notified resource(s).
      * If Puppet makes changes to this resource, it will cause all of the
        notified resources to _refresh._ (Refresh behavior varies by resource
        type: services will restart, mounts will unmount and re-mount, etc. Not
        all types can refresh.)

      This is one of the four relationship metaparameters, along with
      `before`, `require`, and `subscribe`. For more context, including the
      alternate chaining arrow (`->` and `~>`) syntax, see
      [the language page on relationships](https://docs.puppetlabs.com/puppet/latest/reference/lang_relationships.html)."
  end

  newmetaparam(:stage) do
    desc %{Which run stage this class should reside in.

      **Note: This metaparameter can only be used on classes,** and only when
      declaring them with the resource-like syntax. It cannot be used on normal
      resources or on classes declared with `include`.

      By default, all classes are declared in the `main` stage. To assign a class
      to a different stage, you must:

      * Declare the new stage as a [`stage` resource](https://docs.puppetlabs.com/puppet/latest/reference/type.html#stage).
      * Declare an order relationship between the new stage and the `main` stage.
      * Use the resource-like syntax to declare the class, and set the `stage`
        metaparameter to the name of the desired stage.

      For example:

          stage { 'pre':
            before => Stage['main'],
          }

          class { 'apt-updates':
            stage => 'pre',
          }
    }
  end

  newmetaparam(:export, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :NONE}) do
          desc <<EOS
Export a capability resource.

The value of this parameter must be a reference to a capability resource,
or an array of such references. Each capability resource referenced here
will be instantiated in the node catalog and exported to consumers of this
resource. The title of the capability resource will be the title given in
the reference, and all other attributes of the resource will be filled
according to the corresponding produces statement.

It is an error if this metaparameter references resources whose type is not
a capability type, or of there is no produces clause for the type of the
current resource and the capability resource mentioned in this parameter.

For example:

define web(..) { .. }
Web produces Http { .. }
web { server:
  export => Http[main_server]
}
EOS
  end

  newmetaparam(:consume, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :NONE}) do
          desc <<EOS
Consume a capability resource.

The value of this parameter must be a reference to a capability resource,
or an array of such references. Each capability resource referenced here
must have been exported by another resource in the same environment.

The referenced capability resource(s) will be looked up, added to the
current node catalog, and processed following the underlying consumes
clause.

It is an error if this metaparameter references resources whose type is not
a capability type, or of there is no consumes clause for the type of the
current resource and the capability resource mentioned in this parameter.

For example:

define web(..) { .. }
Web consumes Sql { .. }
web { server:
  consume => Sql[my_db]
}
EOS
end

  ###############################
  # All of the provider plumbing for the resource types.
  require 'puppet/provider'
  require 'puppet/util/provider_features'

  # Add the feature handling module.
  extend Puppet::Util::ProviderFeatures

  # The provider that has been selected for the instance of the resource type.
  # @return [Puppet::Provider,nil] the selected provider or nil, if none has been selected
  #
  attr_reader :provider

  # the Type class attribute accessors
  class << self
    # The loader of providers to use when loading providers from disk.
    # Although it looks like this attribute provides a way to operate with different loaders of
    # providers that is not the case; the attribute is written when a new type is created,
    # and should not be changed thereafter.
    # @api private
    #
    attr_accessor :providerloader

    # @todo Don't know if this is a name, or a reference to a Provider instance (now marked up as an instance
    #   of Provider.
    # @return [Puppet::Provider, nil] The default provider for this type, or nil if non is defines
    #
    attr_writer :defaultprovider
  end

  # The default provider, or the most suitable provider if no default provider was set.
  # @note a warning will be issued if no default provider has been configured and a search for the most
  #   suitable provider returns more than one equally suitable provider.
  # @return [Puppet::Provider, nil] the default or most suitable provider, or nil if no provider was found
  #
  def self.defaultprovider
    return @defaultprovider if @defaultprovider

    suitable = suitableprovider

    # Find which providers are a default for this system.
    defaults = suitable.find_all { |provider| provider.default? }

    # If we don't have any default we use suitable providers
    defaults = suitable if defaults.empty?
    max = defaults.collect { |provider| provider.specificity }.max
    defaults = defaults.find_all { |provider| provider.specificity == max }

    if defaults.length > 1
      Puppet.warning(
        "Found multiple default providers for #{self.name}: #{defaults.collect { |i| i.name.to_s }.join(", ")}; using #{defaults[0].name}"
      )
    end

    @defaultprovider = defaults.shift unless defaults.empty?
  end

  # @return [Hash{??? => Puppet::Provider}] Returns a hash of WHAT EXACTLY for the given type
  # @todo what goes into this hash?
  def self.provider_hash_by_type(type)
    @provider_hashes ||= {}
    @provider_hashes[type] ||= {}
  end

  # @return [Hash{ ??? => Puppet::Provider}] Returns a hash of WHAT EXACTLY for this type.
  # @see provider_hash_by_type method to get the same for some other type
  def self.provider_hash
    Puppet::Type.provider_hash_by_type(self.name)
  end

  # Returns the provider having the given name.
  # This will load a provider if it is not already loaded. The returned provider is the first found provider
  # having the given name, where "first found" semantics is defined by the {providerloader} in use.
  #
  # @param name [String] the name of the provider to get
  # @return [Puppet::Provider, nil] the found provider, or nil if no provider of the given name was found
  #
  def self.provider(name)
    name = name.intern

    # If we don't have it yet, try loading it.
    @providerloader.load(name) unless provider_hash.has_key?(name)
    provider_hash[name]
  end

  # Returns a list of loaded providers by name.
  # This method will not load/search for available providers.
  # @return [Array<String>] list of loaded provider names
  #
  def self.providers
    provider_hash.keys
  end

  # Returns true if the given name is a reference to a provider and if this is a suitable provider for
  # this type.
  # @todo How does the provider know if it is suitable for the type? Is it just suitable for the platform/
  #   environment where this method is executing?
  # @param name [String] the name of the provider for which validity is checked
  # @return [Boolean] true if the given name references a provider that is suitable
  #
  def self.validprovider?(name)
    name = name.intern

    (provider_hash.has_key?(name) && provider_hash[name].suitable?)
  end

  # Creates a new provider of a type.
  # This method must be called directly on the type that it's implementing.
  # @todo Fix Confusing Explanations!
  #   Is this a new provider of a Type (metatype), or a provider of an instance of Type (a resource), or
  #   a Provider (the implementation of a Type's behavior). CONFUSED. It calls magically named methods like
  #   "providify" ...
  # @param name [String, Symbol] the name of the WHAT? provider? type?
  # @param options [Hash{Symbol => Object}] a hash of options, used by this method, and passed on to {#genclass}, (see
  #   it for additional options to pass).
  # @option options [Puppet::Provider] :parent the parent provider (what is this?)
  # @option options [Puppet::Type] :resource_type the resource type, defaults to this type if unspecified
  # @return [Puppet::Provider] a provider ???
  # @raise [Puppet::DevError] when the parent provider could not be found.
  #
  def self.provide(name, options = {}, &block)
    name = name.intern

    if unprovide(name)
      Puppet.debug "Reloading #{name} #{self.name} provider"
    end

    parent = if pname = options[:parent]
      options.delete(:parent)
      if pname.is_a? Class
        pname
      else
        if provider = self.provider(pname)
          provider
        else
          raise Puppet::DevError,
            "Could not find parent provider #{pname} of #{name}"
        end
      end
    else
      Puppet::Provider
    end

    options[:resource_type] ||= self

    self.providify

    provider = genclass(
      name,
      :parent     => parent,
      :hash       => provider_hash,
      :prefix     => "Provider",
      :block      => block,
      :include    => feature_module,
      :extend     => feature_module,
      :attributes => options
    )

    provider
  end

  # Ensures there is a `:provider` parameter defined.
  # Should only be called if there are providers.
  # @return [void]
  def self.providify
    return if @paramhash.has_key? :provider

    param = newparam(:provider) do
      # We're using a hacky way to get the name of our type, since there doesn't
      # seem to be a correct way to introspect this at the time this code is run.
      # We expect that the class in which this code is executed will be something
      # like Puppet::Type::Ssh_authorized_key::ParameterProvider.
      desc <<-EOT
        The specific backend to use for this `#{self.to_s.split('::')[2].downcase}`
        resource. You will seldom need to specify this --- Puppet will usually
        discover the appropriate provider for your platform.
      EOT

      # This is so we can refer back to the type to get a list of
      # providers for documentation.
      class << self
        # The reference to a parent type for the parameter `:provider` used to get a list of
        # providers for documentation purposes.
        #
        attr_accessor :parenttype
      end

      # Provides the ability to add documentation to a provider.
      #
      def self.doc
        # Since we're mixing @doc with text from other sources, we must normalize
        # its indentation with scrub. But we don't need to manually scrub the
        # provider's doc string, since markdown_definitionlist sanitizes its inputs.
        scrub(@doc) + "Available providers are:\n\n" + parenttype.providers.sort { |a,b|
          a.to_s <=> b.to_s
        }.collect { |i|
          markdown_definitionlist( i, scrub(parenttype().provider(i).doc) )
        }.join
      end

      # For each resource, the provider param defaults to
      # the type's default provider
      defaultto {
        prov = @resource.class.defaultprovider
        prov.name if prov
      }

      validate do |provider_class|
        provider_class = provider_class[0] if provider_class.is_a? Array
        provider_class = provider_class.class.name if provider_class.is_a?(Puppet::Provider)

        unless @resource.class.provider(provider_class)
          raise ArgumentError, "Invalid #{@resource.class.name} provider '#{provider_class}'"
        end
      end

      munge do |provider|
        provider = provider[0] if provider.is_a? Array
        provider = provider.intern if provider.is_a? String
        @resource.provider = provider

        if provider.is_a?(Puppet::Provider)
          provider.class.name
        else
          provider
        end
      end
    end
    param.parenttype = self
  end

  # @todo this needs a better explanation
  # Removes the implementation class of a given provider.
  # @return [Object] returns what {Puppet::Util::ClassGen#rmclass} returns
  def self.unprovide(name)
    if @defaultprovider and @defaultprovider.name == name
      @defaultprovider = nil
    end

    rmclass(name, :hash => provider_hash, :prefix => "Provider")
  end

  # Returns a list of suitable providers for the given type.
  # A call to this method will load all providers if not already loaded and ask each if it is
  # suitable - those that are are included in the result.
  # @note This method also does some special processing which rejects a provider named `:fake` (for testing purposes).
  # @return [Array<Puppet::Provider>] Returns an array of all suitable providers.
  #
  def self.suitableprovider
    providerloader.loadall if provider_hash.empty?
    provider_hash.find_all { |name, provider|
      provider.suitable?
    }.collect { |name, provider|
      provider
    }.reject { |p| p.name == :fake } # For testing
  end

  # @return [Boolean] Returns true if this is something else than a `:provider`, or if it
  #   is a provider and it is suitable, or if there is a default provider. Otherwise, false is returned.
  #
  def suitable?
    # If we don't use providers, then we consider it suitable.
    return true unless self.class.paramclass(:provider)

    # We have a provider and it is suitable.
    return true if provider && provider.class.suitable?

    # We're using the default provider and there is one.
    if !provider and self.class.defaultprovider
      self.provider = self.class.defaultprovider.name
      return true
    end

    # We specified an unsuitable provider, or there isn't any suitable
    # provider.
    false
  end

  # Sets the provider to the given provider/name.
  # @overload provider=(name)
  #   Sets the provider to the result of resolving the name to an instance of Provider.
  #   @param name [String] the name of the provider
  # @overload provider=(provider)
  #   Sets the provider to the given instances of Provider.
  #   @param provider [Puppet::Provider] the provider to set
  # @return [Puppet::Provider] the provider set
  # @raise [ArgumentError] if the provider could not be found/resolved.
  #
  def provider=(name)
    if name.is_a?(Puppet::Provider)
      @provider = name
      @provider.resource = self
    elsif klass = self.class.provider(name)
      @provider = klass.new(self)
    else
      raise ArgumentError, "Could not find #{name} provider of #{self.class.name}"
    end
  end

  ###############################
  # All of the relationship code.

  # Adds a block producing a single name (or list of names) of the given
  # resource type name to autorelate.
  #
  # The four relationship types require, before, notify, and subscribe are all
  # supported.
  #
  # Be *careful* with notify and subscribe as they may have unintended
  # consequences.
  #
  # Resources in the catalog that have the named type and a title that is
  # included in the result will be linked to the calling resource as a
  # requirement.
  #
  # @example Autorequire the files File['foo', 'bar']
  #   autorequire( 'file', {|| ['foo', 'bar'] })
  #
  # @example Autobefore the files File['foo', 'bar']
  #   autobefore( 'file', {|| ['foo', 'bar'] })
  #
  # @example Autosubscribe the files File['foo', 'bar']
  #   autosubscribe( 'file', {|| ['foo', 'bar'] })
  #
  # @example Autonotify the files File['foo', 'bar']
  #   autonotify( 'file', {|| ['foo', 'bar'] })
  #
  # @param name [String] the name of a type of which one or several resources should be autorelated e.g. "file"
  # @yield [ ] a block returning list of names of given type to auto require
  # @yieldreturn [String, Array<String>] one or several resource names for the named type
  # @return [void]
  # @dsl type
  # @api public
  #
  def self.autorequire(name, &block)
    @autorequires ||= {}
    @autorequires[name] = block
  end

  def self.autobefore(name, &block)
    @autobefores ||= {}
    @autobefores[name] = block
  end

  def self.autosubscribe(name, &block)
    @autosubscribes ||= {}
    @autosubscribes[name] = block
  end

  def self.autonotify(name, &block)
    @autonotifies ||= {}
    @autonotifies[name] = block
  end

  # Provides iteration over added auto-requirements (see {autorequire}).
  # @yieldparam type [String] the name of the type to autorequire an instance of
  # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autorequire}).
  # @yieldreturn [void]
  # @return [void]
  def self.eachautorequire
    @autorequires ||= {}
    @autorequires.each { |type, block|
      yield(type, block)
    }
  end

  # Provides iteration over added auto-requirements (see {autobefore}).
  # @yieldparam type [String] the name of the type to autorequire an instance of
  # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autobefore}).
  # @yieldreturn [void]
  # @return [void]
  def self.eachautobefore
    @autobefores ||= {}
    @autobefores.each { |type,block|
      yield(type, block)
    }
  end

  # Provides iteration over added auto-requirements (see {autosubscribe}).
  # @yieldparam type [String] the name of the type to autorequire an instance of
  # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autosubscribe}).
  # @yieldreturn [void]
  # @return [void]
  def self.eachautosubscribe
    @autosubscribes ||= {}
    @autosubscribes.each { |type,block|
      yield(type, block)
    }
  end

  # Provides iteration over added auto-requirements (see {autonotify}).
  # @yieldparam type [String] the name of the type to autorequire an instance of
  # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autonotify}).
  # @yieldreturn [void]
  # @return [void]
  def self.eachautonotify
    @autonotifies ||= {}
    @autonotifies.each { |type,block|
      yield(type, block)
    }
  end

  # Adds dependencies to the catalog from added autorelations.
  # See {autorequire} for how to add an auto-requirement.
  # @todo needs details - see the param rel_catalog, and type of this param
  # @param rel_catalog [Puppet::Resource::Catalog, nil] the catalog to
  #   add dependencies to. Defaults to the current catalog (set when the
  #   type instance was added to a catalog)
  # @raise [Puppet::DevError] if there is no catalog
  #
  def autorelation(rel_type, rel_catalog = nil)
    rel_catalog ||= catalog
    raise(Puppet::DevError, "You cannot add relationships without a catalog") unless rel_catalog

    reqs = []

    auto_rel = "eachauto#{rel_type}".to_sym

    self.class.send(auto_rel) { |type, block|
      # Ignore any types we can't find, although that would be a bit odd.
      next unless Puppet::Type.type(type)

      # Retrieve the list of names from the block.
      next unless list = self.instance_eval(&block)
      list = [list] unless list.is_a?(Array)

      # Collect the current prereqs
      list.each { |dep|
        next if dep.nil?

        # Support them passing objects directly, to save some effort.
        unless dep.is_a?(Puppet::Type)
          # Skip autorelation that we aren't managing
          unless dep = rel_catalog.resource(type, dep)
            next
          end
        end

        if [:require, :subscribe].include?(rel_type)
          reqs << Puppet::Relationship.new(dep, self)
        else
          reqs << Puppet::Relationship.new(self, dep)
        end
      }
    }

    reqs
  end

  def autorequire(rel_catalog = nil)
    autorelation(:require, rel_catalog)
  end

  def autobefore(rel_catalog = nil)
    autorelation(:before, rel_catalog)
  end

  def autosubscribe(rel_catalog = nil)
    autorelation(:subscribe, rel_catalog)
  end

  def autonotify(rel_catalog = nil)
    autorelation(:notify, rel_catalog)
  end

  # Builds the dependencies associated with this resource.
  #
  # @return [Array<Puppet::Relationship>] list of relationships to other resources
  def builddepends
    # Handle the requires
    self.class.relationship_params.collect do |klass|
      if param = @parameters[klass.name]
        param.to_edges
      end
    end.flatten.reject { |r| r.nil? }
  end

  # Sets the initial list of tags to associate to this resource.
  #
  # @return [void] ???
  def tags=(list)
    tag(self.class.name)
    tag(*list)
  end

  # @comment - these two comments were floating around here, and turned up as documentation
  #  for the attribute "title", much to my surprise and amusement. Clearly these comments
  #  are orphaned ... I think they can just be removed as what they say should be covered
  #  by the now added yardoc. <irony>(Yo! to quote some of the other actual awesome specific comments applicable
  #  to objects called from elsewhere, or not. ;-)</irony>
  #
  # @comment Types (which map to resources in the languages) are entirely composed of
  #   attribute value pairs.  Generally, Puppet calls any of these things an
  #   'attribute', but these attributes always take one of three specific
  #   forms:  parameters, metaparams, or properties.

  # @comment In naming methods, I have tried to consistently name the method so
  #   that it is clear whether it operates on all attributes (thus has 'attr' in
  #   the method name, or whether it operates on a specific type of attributes.

  # The title attribute of WHAT ???
  # @todo Figure out what this is the title attribute of (it appears on line 1926 currently).
  # @return [String] the title
  attr_writer :title

  # The noop attribute of WHAT ??? does WHAT???
  # @todo Figure out what this is the noop attribute of (it appears on line 1931 currently).
  # @return [???] the noop WHAT ??? (mode? if so of what, or noop for an instance of the type, or for all
  #   instances of a type, or for what???
  #
  attr_writer :noop

  include Enumerable

  # class methods dealing with Type management

  public

  # The Type class attribute accessors
  class << self
    # @return [String] the name of the resource type; e.g., "File"
    #
    attr_reader :name

    # @return [Boolean] true if the type should send itself a refresh event on change.
    #
    attr_accessor :self_refresh
    include Enumerable, Puppet::Util::ClassGen
    include Puppet::MetaType::Manager

    include Puppet::Util
    include Puppet::Util::Logging
  end

  # Initializes all of the variables that must be initialized for each subclass.
  # @todo Does the explanation make sense?
  # @return [void]
  def self.initvars
    # all of the instances of this class
    @objects = Hash.new
    @aliases = Hash.new

    @defaults = {}

    @parameters ||= []

    @validproperties = {}
    @properties = []
    @parameters = []
    @paramhash = {}

    @paramdoc = Hash.new { |hash,key|
      key = key.intern if key.is_a?(String)
      if hash.include?(key)
        hash[key]
      else
        "Param Documentation for #{key} not found"
      end
    }

    @doc ||= ""

  end

  # Returns the name of this type (if specified) or the parent type #to_s.
  # The returned name is on the form "Puppet::Type::<name>", where the first letter of name is
  # capitalized.
  # @return [String] the fully qualified name Puppet::Type::<name> where the first letter of name is capitalized
  #
  def self.to_s
    if defined?(@name)
      "Puppet::Type::#{@name.to_s.capitalize}"
    else
      super
    end
  end

  # Creates a `validate` method that is used to validate a resource before it is operated on.
  # The validation should raise exceptions if the validation finds errors. (It is not recommended to
  # issue warnings as this typically just ends up in a logfile - you should fail if a validation fails).
  # The easiest way to raise an appropriate exception is to call the method {Puppet::Util::Errors.fail} with
  # the message as an argument.
  #
  # @yield [ ] a required block called with self set to the instance of a Type class representing a resource.
  # @return [void]
  # @dsl type
  # @api public
  #
  def self.validate(&block)
    define_method(:validate, &block)
  end

  # @return [String] The file from which this type originates from
  attr_accessor :file

  # @return [Integer] The line in {#file} from which this type originates from
  attr_accessor :line

  # @todo what does this mean "this resource" (sounds like this if for an instance of the type, not the meta Type),
  #   but not sure if this is about the catalog where the meta Type is included)
  # @return [??? TODO] The catalog that this resource is stored in.
  attr_accessor :catalog

  # @return [Boolean] Flag indicating if this type is exported
  attr_accessor :exported

  # @return [Boolean] Flag indicating if the type is virtual (it should not be).
  attr_accessor :virtual

  # Creates a log entry with the given message at the log level specified by the parameter `loglevel`
  # @return [void]
  #
  def log(msg)

    Puppet::Util::Log.create(

      :level => @parameters[:loglevel].value,
      :message => msg,

      :source => self
    )
  end


  # instance methods related to instance intrinsics
  # e.g., initialize and name

  public

  # @return [Hash] hash of parameters originally defined
  # @api private
  attr_reader :original_parameters

  # Creates an instance of Type from a hash or a {Puppet::Resource}.
  # @todo Unclear if this is a new Type or a new instance of a given type (the initialization ends
  #   with calling validate - which seems like validation of an instance of a given type, not a new
  #   meta type.
  #
  # @todo Explain what the Hash and Resource are. There seems to be two different types of
  #   resources; one that causes the title to be set to resource.title, and one that
  #   causes the title to be resource.ref ("for components") - what is a component?
  #
  # @overload initialize(hash)
  #   @param [Hash] hash
  #   @raise [Puppet::ResourceError] when the type validation raises
  #     Puppet::Error or ArgumentError
  # @overload initialize(resource)
  #   @param resource [Puppet:Resource]
  #   @raise [Puppet::ResourceError] when the type validation raises
  #     Puppet::Error or ArgumentError
  #
  def initialize(resource)
    resource = self.class.hash2resource(resource) unless resource.is_a?(Puppet::Resource)

    # The list of parameter/property instances.
    @parameters = {}

    # Set the title first, so any failures print correctly.
    if resource.type.to_s.downcase.to_sym == self.class.name
      self.title = resource.title
    else
      # This should only ever happen for components
      self.title = resource.ref
    end

    [:file, :line, :catalog, :exported, :virtual].each do |getter|
      setter = getter.to_s + "="
      if val = resource.send(getter)
        self.send(setter, val)
      end
    end

    @tags = resource.tags

    @original_parameters = resource.to_hash

    set_name(@original_parameters)

    set_default(:provider)

    set_parameters(@original_parameters)

    begin
      self.validate if self.respond_to?(:validate)
    rescue Puppet::Error, ArgumentError => detail
      error = Puppet::ResourceError.new("Validation of #{ref} failed: #{detail}")
      adderrorcontext(error, detail)
      raise error
    end

    set_sensitive_parameters(resource.sensitive_parameters)
  end

  protected

  # Mark parameters associated with this type as sensitive, based on the associated resource.
  #
  # Currently, only instances of `Puppet::Property` can be easily marked for sensitive data handling
  # and information redaction is limited to redacting events generated while synchronizing
  # properties. While support for redaction will be broadened in the future we can't automatically
  # deduce how to redact arbitrary parameters, so if a parameter is marked for redaction the best
  # we can do is warn that we can't handle treating that parameter as sensitive and move on.
  #
  # In some unusual cases a given parameter will be marked as sensitive but that sensitive context
  # needs to be transferred to another parameter. In this case resource types may need to override
  # this method in order to copy the sensitive context from one parameter to another (and in the
  # process force the early generation of a parameter that might otherwise be lazily generated.)
  # See `Puppet::Type.type(:file)#set_sensitive_parameters` for an example of this.
  #
  # @note This method visibility is protected since it should only be called by #initialize, but is
  #   marked as public as subclasses may need to override this method.
  #
  # @api public
  #
  # @param sensitive_parameters [Array<Symbol>] A list of parameters to mark as sensitive.
  #
  # @return [void]
  def set_sensitive_parameters(sensitive_parameters)
    sensitive_parameters.each do |name|
      p = parameter(name)
      if p.is_a?(Puppet::Property)
        p.sensitive = true
      elsif p.is_a?(Puppet::Parameter)
        warning("Unable to mark '#{name}' as sensitive: #{name} is a parameter and not a property, and cannot be automatically redacted.")
      elsif self.class.attrclass(name)
        warning("Unable to mark '#{name}' as sensitive: the property itself was not assigned a value.")
      else
        err("Unable to mark '#{name}' as sensitive: the property itself is not defined on #{type}.")
      end
    end
  end

  private

  # Sets the name of the resource from a hash containing a mapping of `name_var` to value.
  # Sets the value of the property/parameter appointed by the `name_var` (if it is defined). The value set is
  # given by the corresponding entry in the given hash - e.g. if name_var appoints the name `:path` the value
  # of `:path` is set to the value at the key `:path` in the given hash. As a side effect this key/value is then
  # removed from the given hash.
  #
  # @note This method mutates the given hash by removing the entry with a key equal to the value
  #   returned from name_var!
  # @param hash [Hash] a hash of what
  # @return [void]
  def set_name(hash)
    self[name_var] = hash.delete(name_var) if name_var
  end

  # Sets parameters from the given hash.
  # Values are set in _attribute order_ i.e. higher priority attributes before others, otherwise in
  # the order they were specified (as opposed to just setting them in the order they happen to appear in
  # when iterating over the given hash).
  #
  # Attributes that are not included in the given hash are set to their default value.
  #
  # @todo Is this description accurate? Is "ensure" an example of such a higher priority attribute?
  # @return [void]
  # @raise [Puppet::DevError] when impossible to set the value due to some problem
  # @raise [ArgumentError, TypeError, Puppet::Error] when faulty arguments have been passed
  #
  def set_parameters(hash)
    # Use the order provided by allattrs, but add in any
    # extra attributes from the resource so we get failures
    # on invalid attributes.
    no_values = []
    (self.class.allattrs + hash.keys).uniq.each do |attr|
      begin
        # Set any defaults immediately.  This is mostly done so
        # that the default provider is available for any other
        # property validation.
        if hash.has_key?(attr)
          self[attr] = hash[attr]
        else
          no_values << attr
        end
      rescue ArgumentError, Puppet::Error, TypeError
        raise
      rescue => detail
        error = Puppet::DevError.new( "Could not set #{attr} on #{self.class.name}: #{detail}")
        error.set_backtrace(detail.backtrace)
        raise error
      end
    end
    no_values.each do |attr|
      set_default(attr)
    end
  end

  public

  # Finishes any outstanding processing.
  # This method should be called as a final step in setup,
  # to allow the parameters that have associated auto-require needs to be processed.
  #
  # @todo what is the expected sequence here - who is responsible for calling this? When?
  #   Is the returned type correct?
  # @return [Array<Puppet::Parameter>] the validated list/set of attributes
  #
  def finish
    # Call post_compile hook on every parameter that implements it. This includes all subclasses
    # of parameter including, but not limited to, regular parameters, metaparameters, relationship
    # parameters, and properties.
    eachparameter do |parameter|
      parameter.post_compile if parameter.respond_to? :post_compile
    end

    # Make sure all of our relationships are valid.  Again, must be done
    # when the entire catalog is instantiated.
    self.class.relationship_params.collect do |klass|
      if param = @parameters[klass.name]
        param.validate_relationship
      end
    end.flatten.reject { |r| r.nil? }
  end

  # @comment For now, leave the 'name' method functioning like it used to.  Once 'title'
  #   works everywhere, I'll switch it.
  # Returns the resource's name
  # @todo There is a comment in source that this is not quite the same as ':title' and that a switch should
  #   be made...
  # @return [String] the name of a resource
  def name
    self[:name]
  end

  # Returns the parent of this in the catalog.  In case of an erroneous catalog
  # where multiple parents have been produced, the first found (non
  # deterministic) parent is returned.
  # @return [Puppet::Type, nil] the
  #   containing resource or nil if there is no catalog or no containing
  #   resource.
  def parent
    return nil unless catalog

    @parent ||=
      if parents = catalog.adjacent(self, :direction => :in)
        parents.shift
      else
        nil
      end
  end

  # Returns a reference to this as a string in "Type[name]" format.
  # @return [String] a reference to this object on the form 'Type[name]'
  #
  def ref
    # memoizing this is worthwhile ~ 3 percent of calls are the "first time
    # around" in an average run of Puppet. --daniel 2012-07-17
    @ref ||= "#{self.class.name.to_s.capitalize}[#{self.title}]"
  end

  # (see self_refresh)
  # @todo check that meaningful yardoc is produced - this method delegates to "self.class.self_refresh"
  # @return [Boolean] - ??? returns true when ... what?
  #
  def self_refresh?
    self.class.self_refresh
  end

  # Marks the object as "being purged".
  # This method is used by transactions to forbid deletion when there are dependencies.
  # @todo what does this mean; "mark that we are purging" (purging what from where). How to use/when?
  #   Is this internal API in transactions?
  # @see purging?
  def purging
    @purging = true
  end

  # Returns whether this resource is being purged or not.
  # This method is used by transactions to forbid deletion when there are dependencies.
  # @return [Boolean] the current "purging" state
  #
  def purging?
    if defined?(@purging)
      @purging
    else
      false
    end
  end

  # Returns the title of this object, or its name if title was not explicitly set.
  # If the title is not already set, it will be computed by looking up the {#name_var} and using
  # that value as the title.
  # @todo it is somewhat confusing that if the name_var is a valid parameter, it is assumed to
  #  be the name_var called :name, but if it is a property, it uses the name_var.
  #  It is further confusing as Type in some respects supports multiple namevars.
  #
  # @return [String] Returns the title of this object, or its name if title was not explicitly set.
  # @raise [??? devfail] if title is not set, and name_var can not be found.
  def title
    unless @title
      if self.class.validparameter?(name_var)
        @title = self[:name]
      elsif self.class.validproperty?(name_var)
        @title = self.should(name_var)
      else
        self.devfail "Could not find namevar #{name_var} for #{self.class.name}"
      end
    end

    @title
  end

  # Produces a reference to this in reference format.
  # @see #ref
  #
  def to_s
    self.ref
  end

  # Convert this resource type instance to a Puppet::Resource.
  # @return [Puppet::Resource] Returns a serializable representation of this resource
  #
  def to_resource
    resource = self.retrieve_resource
    resource.tag(*self.tags)

    @parameters.each do |name, param|
      # Avoid adding each instance name twice
      next if param.class.isnamevar? and param.value == self.title

      # We've already got property values
      next if param.is_a?(Puppet::Property)
      resource[name] = param.value
    end

    resource
  end

  # @return [Boolean] Returns whether the resource is virtual or not
  def virtual?;  !!@virtual;  end
  # @return [Boolean] Returns whether the resource is exported or not
  def exported?; !!@exported; end

  # @return [Boolean] Returns whether the resource is applicable to `:device`
  # Returns true if a resource of this type can be evaluated on a 'network device' kind
  # of hosts.
  # @api private
  def appliable_to_device?
    self.class.can_apply_to(:device)
  end

  # @return [Boolean] Returns whether the resource is applicable to `:host`
  # Returns true if a resource of this type can be evaluated on a regular generalized computer (ie not an appliance like a network device)
  # @api private
  def appliable_to_host?
    self.class.can_apply_to(:host)
  end
end
end
