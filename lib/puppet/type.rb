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

  # @return [Boolean] Returns true if the wanted state of the resource is that it should be absent (i.e. to be deleted).
  def deleting?
    obj = @parameters[:ensure] and obj.should == :absent
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

  # @return [Object, nil] Returns the 'should' (wanted state) value for a specified property, or nil if the
  #   given attribute name is not a property (i.e. if it is a parameter, meta-parameter, or does not exist).
  def should(name)
    name = name.intern
    (prop = @parameters[name] and prop.is_a?(Puppet::Property)) ? prop.should : nil
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
  # @todo (DS) this seems to be only called in spec tests and providers, in the latter to enable `command` to work.
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
end
end

require 'puppet/type_guts/app_orchestration'
require 'puppet/type_guts/automatic_relationships'
require 'puppet/type_guts/comparable'
require 'puppet/type_guts/creating_attributes'
require 'puppet/type_guts/device_applicability'
require 'puppet/type_guts/key_attributes'
require 'puppet/type_guts/provider'
require 'puppet/type_guts/querying_attributes_original'
require 'puppet/type_guts/utilities'

# these need to go last, since they rely on all the infrastructure being in place
require 'puppet/type_guts/attribute_definitions'
