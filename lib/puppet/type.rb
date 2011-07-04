require 'puppet'
require 'puppet/util/log'
require 'puppet/util/metric'
require 'puppet/property'
require 'puppet/parameter'
require 'puppet/util'
require 'puppet/util/autoload'
require 'puppet/util/errors'
require 'puppet/util/log_paths'
require 'puppet/util/logging'
require 'puppet/util/tagging'

# see the bottom of the file for the rest of the inclusions

module Puppet
class Type
  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::LogPaths
  include Puppet::Util::Logging
  include Puppet::Util::Tagging

  ###
  # This was all in metatype/manager.rb, for no real reason.
  include Puppet::Util::ClassGen

  # remove all type instances; this is mostly only useful for testing
  def self.allclear
    @types.each { |name, type|
      type.clear
    }
  end

  # iterate across all of the subclasses of Type
  def self.eachtype
    @types.each do |name, type|
      yield type
    end
  end

  # Load all types.  Only currently used for documentation.
  def self.loadall
    typeloader.loadall
  end

  # Define a new type.
  def self.newtype(name, options = {}, &block)
    # Handle backward compatibility
    unless options.is_a?(Hash)
      Puppet.warning "Puppet::Type.newtype(#{name}) now expects a hash as the second argument, not #{options.inspect}"
      options = {:parent => options}
    end

    # First make sure we don't have a method sitting around
    name = name.intern
    newmethod = "new#{name.to_s}"

    # Used for method manipulation.
    selfobj = singleton_class

    @types ||= {}

    if @types.include?(name)
      if self.respond_to?(newmethod)
        # Remove the old newmethod
        selfobj.send(:remove_method,newmethod)
      end
    end

    options = symbolize_options(options)

    if parent = options[:parent]
      options.delete(:parent)
    end

    # Then create the class.

    klass = genclass(
      name,
      :parent => (parent || Puppet::Type),
      :overwrite => true,
      :hash => @types,
      :attributes => options,
      &block
    )

    # Now define a "new<type>" method for convenience.
    if self.respond_to? newmethod
      # Refuse to overwrite existing methods like 'newparam' or 'newtype'.
      Puppet.warning "'new#{name.to_s}' method already exists; skipping"
    else
      selfobj.send(:define_method, newmethod) do |*args|
        klass.new(*args)
      end
    end

    # If they've got all the necessary methods defined and they haven't
    # already added the property, then do so now.
    klass.ensurable if klass.ensurable? and ! klass.validproperty?(:ensure)

    # Now set up autoload any providers that might exist for this type.

    klass.providerloader = Puppet::Util::Autoload.new(
      klass,
      "puppet/provider/#{klass.name.to_s}"
    )

    # This can only happen when the type is reloaded in memory and the providers
    # are still there
    unless klass.provider_hash.empty?
      klass.providify
    end

    # We have to load everything so that we can figure out the default type.
    klass.providerloader.loadall

    klass
  end

  # Remove an existing defined type.  Largely used for testing.
  def self.rmtype(name)

    klass = rmclass(
      name,
      :hash => @types
    )

    singleton_class.send(:remove_method, "new#{name}") if respond_to?("new#{name}")
  end

  # Return a Type instance by name.
  def self.type(name)
    @types ||= {}

    name = name.to_s.downcase.to_sym

    if t = @types[name]
      return t
    else
      if typeloader.load(name)
        Puppet.warning "Loaded puppet/type/#{name} but no class was created" unless @types.include? name
      end

      return @types[name]
    end
  end

  # Create a loader for Puppet types.
  def self.typeloader
    unless defined?(@typeloader)
      @typeloader = Puppet::Util::Autoload.new(
        self,
        "puppet/type", :wrap => false
      )
    end

    @typeloader
  end

  ###############################
  # Comparing type instances.
  include Comparable
  def <=>(other)
    # We only order against other types, not arbitrary objects.
    return nil unless other.is_a? Puppet::Type
    # Our natural order is based on the reference name we use when comparing
    # against other type instances.
    self.ref <=> other.ref
  end

  ###############################
  # Code related to resource type attributes.
  class << self
    include Puppet::Util::ClassGen
    include Puppet::Util::Warnings
  end

  ###############################
  # New paramcode to define the new interface

  # A method for adding a new parameter to the list of known parameters.
  # These variables should never be accessed directly anywhere other than the
  # gate methods defined here.
  def self.add_parameter_class(klass)
    @parameters ||= []

    @parameters_fully_ordered ||= []
    @parameters_fully_ordered << klass

    @parameters << klass
    @parameters.sort! { |a,b|
      case
      when a.isnamevar? || (a.name == :name)
        -1
      when b.isnamevar? || (b.name == :name)
        1
      when a.name == :provider
        -1
      when b.name == :provider
        1
      when a.name == :ensure
        -1
      when b.name == :ensure
        1
      when a.parameter? && b.property?
        -1
      when a.property? && b.parameter?
        1
      else
        @parameters_fully_ordered.index(a) <=> @parameters_fully_ordered.index(b)
      end
    }
    @parameters_by_name ||= {}
    @parameters_by_name[klass.name] = klass
  end

  # Return the list of all parameter classes supported by this class.
  # Always includes metaparameters.
  def self.parameters
    @parameters ||= []

    # We're doing something slightly magical here - if a parameter
    # are defined in Puppet::Type (rather than a subclass), then it's
    # a metaparam.  Thus, we have to behave a bit differently if we're
    # the base class.
    if self == Puppet::Type
      @parameters.dup
    else
      @parameters + metaparameters
    end
  end

  def self.parameter_names
    parameters.collect { |p| p.name }
  end

  # This returns the class for a given parameter, or nil.
  def self.parameter(name)
    name = name.to_sym
    @parameters_by_name ||= {}
    if self == Puppet::Type
      @parameters_by_name[name]
    else
      @parameters_by_name[name] || Puppet::Type.parameter(name)
    end
  end

  # What kind of parameter do we have - property, parameter, or metaparameter?
  def self.parameter_type(name)
    name = name.to_sym
    return nil unless klass = parameter(name)
    klass.parameter_type
  end

  # Is the provided name a valid parameter?
  # This method is used in both Puppet::Type and Puppet::Resource.
  def self.valid_parameter?(name)
    name = name.to_sym
    return true if name == :name and self != Puppet::Type
    return true if parameter(name)
    return false
  end

  # Is the parameter in question a meta-parameter?
  def self.metaparam?(param)
    Puppet::Type.valid_parameter?(param)
  end

  def self.metaparameter(name)
    Puppet::Type.parameter(name)
  end

  def self.metaparameters
    Puppet::Type.parameters
  end

  # All new code in this block
  #############################

  #############################
  # This code should probably all be removed
  # All parameters, in the appropriate order.  The key_attributes come first, then
  # the provider, then the properties, and finally the params and metaparams
  # in the order they were specified in the files.
  def self.metaparams
    metaparameters
  end

  def self.properties
    parameters.find_all { |p| p.property? }
  end

  # What type of parameter are we dealing with? Cache the results, because
  # this method gets called so many times.
  def self.attrtype(attr)
    parameter_type(attr)
  end

  def self.eachmetaparam
    parameters.each { |p| yield p.name }
  end

  # Find the parameter class associated with a given parameter name.
  def self.paramclass(name)
    parameter(name)
  end

  # Return the property class associated with a name
  def self.propertybyname(name)
    parameter(name)
  end

  def self.validattr?(name)
    valid_parameter?(name)
  end

  # does the name reflect a valid property?
  def self.validproperty?(name)
    p = parameter(name) and p.property?
  end

  # Return the list of validproperties
  def self.validproperties
    parameters.find_all { |p| p.property? }.collect { |p| p.name }
  end

  # does the name reflect a valid parameter?
  def self.validparameter?(name)
    valid_aparameter?(name)
  end
  # end of code likely to be removed
  ##############################

  # Create the 'ensure' class.  This is a separate method so other types
  # can easily call it and create their own 'ensure' values.
  def self.ensurable(&block)
    if block_given?
      self.newproperty(:ensure, :parent => Puppet::Property::Ensure, &block)
    else
      self.newproperty(:ensure, :parent => Puppet::Property::Ensure) do
        self.defaultvalues
      end
    end
  end

  # Should we add the 'ensure' property to this class?
  def self.ensurable?
    # If the class has all three of these methods defined, then it's
    # ensurable.
    [:exists?, :create, :destroy].all? { |method|
      self.public_method_defined?(method)
    }
  end

  # These `apply_to` methods are horrible.  They should really be implemented
  # as part of the usual system of constraints that apply to a type and
  # provider pair, but were implemented as a separate shadow system.
  #
  # We should rip them out in favour of a real constraint pattern around the
  # target device - whatever that looks like - and not have this additional
  # magic here. --daniel 2012-03-08
  def self.apply_to_device
    @apply_to = :device
  end

  def self.apply_to_host
    @apply_to = :host
  end

  def self.apply_to_all
    @apply_to = :both
  end

  def self.apply_to
    @apply_to ||= :host
  end

  def self.can_apply_to(target)
    [ target == :device ? :device : :host, :both ].include?(apply_to)
  end

  # Deal with any options passed into parameters.
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

  # Create a new metaparam.  Requires a block and a name, stores it in the
  # @metaparams array, and does some basic checking on it.
  def self.newmetaparam(name, options = {}, &block)
    raise "Only Puppet::Type can add metaparams" unless self == Puppet::Type

    name = name.intern

    param = genclass(
      name,
      :parent => options[:parent] || Puppet::Parameter,
      :prefix => "MetaParam",
      :attributes => options[:attributes],
      &block
    )

    # Grr.
    param.required_features = options[:required_features] if options[:required_features]

    handle_param_options(name, options)

    param.metaparam = true

    # Parameters stored by Puppet::Type are metaparams, by definition.
    add_parameter_class(param)

    param
  end

  def self.key_attribute_parameters
    @key_attribute_parameters ||= (
      params = parameters.find_all { |param|
        param.isnamevar? or param.name == :name
      }
    )
  end

  def self.key_attributes
    # This is a cache miss around 0.05 percent of the time. --daniel 2012-07-17
    @key_attributes_cache ||= key_attribute_parameters.collect { |p| p.name }
  end

  def self.title_patterns
    case key_attributes.length
    when 0; []
    when 1;
      [ [ /(.*)/m, [ [key_attributes.first] ] ] ]
    else
      raise Puppet::DevError,"you must specify title patterns when there are two or more key attributes"
    end
  end

  def uniqueness_key
    self.class.key_attributes.sort_by { |attribute_name| attribute_name.to_s }.map{ |attribute_name| self[attribute_name] }
  end

  # Create a new parameter.  Requires a block and a name, stores it in the
  # parameter list, and does some basic checking on it.
  def self.newparam(name, options = {}, &block)
    options[:attributes] ||= {}

    param = genclass(
      name,
      :parent     => options[:parent] || Puppet::Parameter,
      :attributes => options[:attributes],
      :block => block,
      :prefix => "Parameter"
    )

    handle_param_options(name, options)

    # Grr.
    param.required_features = options[:required_features] if options[:required_features]

    param.isnamevar if options[:namevar]

    add_parameter_class(param)

    param
  end

  # Create a new property. The first parameter must be the name of the property;
  # this is how users will refer to the property when creating new instances.
  # The second parameter is a hash of options; the options are:
  # * <tt>:parent</tt>: The parent class for the property.  Defaults to Puppet::Property.
  # * <tt>:retrieve</tt>: The method to call on the provider or @parent object (if
  #   the provider is not set) to retrieve the current value.
  def self.newproperty(name, options = {}, &block)
    name = name.intern

    # This is here for types that might still have the old method of defining
    # a parent class.
    unless options.is_a? Hash
      raise Puppet::DevError,
        "Options must be a hash, not #{options.inspect}"
    end

    raise Puppet::DevError, "Class #{self.name} already has a parameter named #{name}" if parameter(name)

    if parent = options[:parent]
      options.delete(:parent)
    else
      parent = Puppet::Property
    end

    # We have to create our own, new block here because we want to define
    # an initial :retrieve method, if told to, and then eval the passed
    # block if available.
    prop = genclass(name, :parent => parent, :attributes => options) do
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
    add_parameter_class(prop)

    prop
  end

  # Are we deleting this resource?
  def deleting?
    obj = @parameters[:ensure] and obj.should == :absent
  end

  #
  # The name_var is the key_attribute in the case that there is only one.
  #
  def name_var
    return @name_var_cache unless @name_var_cache.nil?
    key_attributes = self.class.key_attributes
    @name_var_cache = (key_attributes.length == 1) && key_attributes.first
  end

  # abstract accessing parameters and properties, and normalize access to
  # always be symbols, not strings This returns a value, not an object.
  # It returns the 'is' value, but you can also specifically return 'is' and
  # 'should' values using 'object.is(:property)' or
  # 'object.should(:property)'.
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

  # Abstract setting parameters and properties, and normalize
  # access to always be symbols, not strings.  This sets the 'should'
  # value on properties, and otherwise just sets the appropriate parameter.
  def []=(name,value)
    name = name.intern

    fail("Invalid parameter #{name}") unless self.class.validattr?(name)

    if name == :name && nv = name_var
      name = nv
    end
    raise Puppet::Error.new("Got nil value for #{name}") if value.nil?

    property = self.newattr(name)

    if property
      begin
        # make sure the parameter doesn't have any errors
        property.value = value
      rescue => detail
        error = Puppet::Error.new("Parameter #{name} failed: #{detail}")
        error.set_backtrace(detail.backtrace)
        raise error
      end
    end

    nil
  end

  # remove a property from the object; useful in testing or in cleanup
  # when an error has been encountered
  def delete(attr)
    attr = attr.intern
    if @parameters.has_key?(attr)
      @parameters.delete(attr)
    else
      raise Puppet::DevError.new("Undefined attribute '#{attr}' in #{self}")
    end
  end

  # iterate across the existing properties
  def eachproperty
    # properties is a private method
    properties.each { |property|
      yield property
    }
  end

  # Create a transaction event.  Called by Transaction or by
  # a property.
  def event(options = {})
    Puppet::Transaction::Event.new({:resource => self, :file => file, :line => line, :tags => tags}.merge(options))
  end

  # retrieve the 'should' value for a specified property
  def should(name)
    name = name.intern
    (prop = @parameters[name] and prop.is_a?(Puppet::Property)) ? prop.should : nil
  end

  # Create the actual attribute instance.  Requires either the attribute
  # name or class as the first argument, then an optional hash of
  # attributes to set during initialization.
  def newattr(name)
    if name.is_a?(Class)
      klass = name
      name = klass.name
    end

    unless klass = self.class.parameter(name)
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

  # return the value of a parameter
  def parameter(name)
    @parameters[name.to_sym]
  end

  def parameters
    @parameters.dup
  end

  # Is the named property defined?
  def propertydefined?(name)
    name = name.intern unless name.is_a? Symbol
    @parameters.include?(name)
  end

  # Return an actual property instance by name; to return the value, use 'resource[param]'
  # LAK:NOTE(20081028) Since the 'parameter' method is now a superset of this method,
  # this one should probably go away at some point.
  def property(name)
    (obj = @parameters[name.intern] and obj.is_a?(Puppet::Property)) ? obj : nil
  end

  # For any parameters or properties that have defaults and have not yet been
  # set, set them now.  This method can be handed a list of attributes,
  # and if so it will only set defaults for those attributes.
  def set_default(klass)
    unless klass.is_a?(Class)
      return unless klass = self.class.parameter(klass)
    end
    return unless klass.method_defined?(:default)
    return if @parameters.include?(klass.name)

    return unless parameter = newattr(klass.name)

    if value = parameter.default and ! value.nil?
      parameter.value = value
    else
      @parameters.delete(parameter.name)
    end
  end

  # Convert our object to a hash.  This just includes properties.
  def to_hash
    rethash = {}

    @parameters.each do |name, obj|
      rethash[name] = obj.value
    end

    rethash
  end

  def type
    self.class.name
  end

  # Return a specific value for an attribute.
  def value(name)
    name = name.intern
    (obj = @parameters[name] and obj.respond_to?(:value)) ? obj.value : nil
  end

  def version
    return 0 unless catalog
    catalog.version
  end

  # Return all of the property objects, in the order specified in the
  # class.
  def properties
    self.class.properties.collect { |prop| @parameters[prop.name] }.compact
  end

  # Is this type's name isomorphic with the object?  That is, if the
  # name conflicts, does it necessarily mean that the objects conflict?
  # Defaults to true.
  def self.isomorphic?
    if defined?(@isomorphic)
      return @isomorphic
    else
      return true
    end
  end

  def isomorphic?
    self.class.isomorphic?
  end

  # is the instance a managed instance?  A 'yes' here means that
  # the instance was created from the language, vs. being created
  # in order resolve other questions, such as finding a package
  # in a list
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

  def depthfirst?
    false
  end

  # Remove an object.  The argument determines whether the object's
  # subscriptions get eliminated, too.
  def remove(rmdeps = true)
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

  def ancestors
    []
  end

  # Flush the provider, if it supports it.  This is called by the
  # transaction.
  def flush
    self.provider.flush if self.provider and self.provider.respond_to?(:flush)
  end

  # if all contained objects are in sync, then we're in sync
  # FIXME I don't think this is used on the type instances any more,
  # it's really only used for testing
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

    properties.each { |property|
      unless is.include? property
        raise Puppet::DevError,
          "The is value is not in the is array for '#{property.name}'"
      end

      propis = is[property]
      unless property.safe_insync?(propis)
        property.debug("Not in sync: #{propis.inspect} vs #{property.should.inspect}")
        insync = false
      #else
      #    property.debug("In sync")
      end
    }

    #self.debug("#{self} sync status is #{insync}")
    insync
  end

  # retrieve the current value of all contained properties
  def retrieve
    fail "Provider #{provider.class.name} is not functional on this host" if self.provider.is_a?(Puppet::Provider) and ! provider.class.suitable?

    result = Puppet::Resource.new(type, title)

    # Provide the name, so we know we'll always refer to a real thing
    result[:name] = self[:name] unless self[:name] == title

    if ensure_prop = property(:ensure) or (self.class.validattr?(:ensure) and ensure_prop = newattr(:ensure))
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

  def retrieve_resource
    resource = retrieve
    resource = Resource.new(type, title, :parameters => resource) if resource.is_a? Hash
    resource
  end

  # Get a hash of the current properties.  Returns a hash with
  # the actual property instance as the key and the current value
  # as the, um, value.
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

  # Are we running in noop mode?
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

  def noop
    noop?
  end

  # Retrieve all known instances.  Either requires providers or must be overridden.
  def self.instances
    raise Puppet::DevError, "#{self.name} has no providers and has not overridden 'instances'" if provider_hash.empty?

    # Put the default provider first, then the rest of the suitable providers.
    provider_instances = {}
    providers_by_source.collect do |provider|
      all_properties = self.properties.find_all do |property|
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

  # Return a list of one suitable provider per source, with the default provider first.
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

  # Convert a simple hash into a Resource instance.
  def self.hash2resource(hash)
    hash = hash.inject({}) { |result, ary| result[ary[0].to_sym] = ary[1]; result }

    title = hash.delete(:title)
    title ||= hash[:name]
    title ||= hash[key_attributes.first] if key_attributes.length == 1

    raise Puppet::Error, "Title or name must be provided" unless title

    # Now create our resource.
    resource = Puppet::Resource.new(self.name, title)
    [:catalog].each do |attribute|
      if value = hash[attribute]
        hash.delete(attribute)
        resource.send(attribute.to_s + "=", value)
      end
    end

    hash.each do |param, value|
      resource[param] = value
    end
    resource
  end

  # Create the path for logging and such.
  def pathbuilder
    if p = parent
      [p.pathbuilder, self.ref].flatten
    else
      [self.ref]
    end
  end

  ###############################
  # Add all of the meta parameters.
  newmetaparam(:noop) do
    desc "Boolean flag indicating whether work should actually
      be done."

    newvalues(:true, :false)
    munge do |value|
      case value
      when true, :true, "true"; @resource.noop = true
      when false, :false, "false"; @resource.noop = false
      end
    end
  end

  newmetaparam(:schedule) do
    desc "On what schedule the object should be managed.  You must create a
      schedule object, and then reference the name of that object to use
      that for your schedule:

          schedule { 'daily':
            period => daily,
            range  => \"2-4\"
          }

          exec { \"/usr/bin/apt-get update\":
            schedule => 'daily'
          }

      The creation of the schedule object does not need to appear in the
      configuration before objects that use it."
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

  newmetaparam(:check) do
    desc "Audit specified attributes of resources over time, and report if any have changed.
      This parameter has been deprecated in favor of 'audit'."

    munge do |args|
      Puppet.deprecation_warning "'check' attribute is deprecated; use 'audit' instead"
      resource.warning "'check' attribute is deprecated; use 'audit' instead"
      resource[:audit] = args
    end
  end

  newmetaparam(:loglevel) do
    desc "Sets the level that information will be logged.
      The log levels have the biggest impact when logs are sent to
      syslog (which is currently the default)."
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
    desc "Creates an alias for the object.  Puppet uses this internally when you
      provide a symbolic title:

          file { 'sshdconfig':
            path => $operatingsystem ? {
              solaris => \"/usr/local/etc/ssh/sshd_config\",
              default => \"/etc/ssh/sshd_config\"
            },
            source => \"...\"
          }

          service { 'sshd':
            subscribe => File['sshdconfig']
          }

      When you use this feature, the parser sets `sshdconfig` as the title,
      and the library sets that as an alias for the file so the dependency
      lookup in `Service['sshd']` works.  You can use this metaparameter yourself,
      but note that only the library can use these aliases; for instance,
      the following code will not work:

          file { \"/etc/ssh/sshd_config\":
            owner => root,
            group => root,
            alias => 'sshdconfig'
          }

          file { 'sshdconfig':
            mode => 644
          }

      There's no way here for the Puppet parser to know that these two stanzas
      should be affecting the same file.

      See the [Language Guide](http://docs.puppetlabs.com/guides/language_guide.html) for more information.

      "

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
            mode   => 0644,
            tag    => ['bootstrap', 'minimumrun', 'mediumrun'],
          }

      Tags are useful for things like applying a subset of a host's configuration
      with [the `tags` setting](/references/latest/configuration.html#tags):

          puppet agent --test --tags bootstrap

      This way, you can easily isolate the portion of the configuration you're
      trying to test."

    munge do |tags|
      tags = [tags] unless tags.is_a? Array

      tags.each do |tag|
        @resource.tag(tag)
      end
    end
  end

  class RelationshipMetaparam < Puppet::Parameter
    class << self
      attr_accessor :direction, :events, :callback, :subclasses
    end

    @subclasses = []

    def self.inherited(sub)
      @subclasses << sub
    end

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

    def validate_relationship
      @value.each do |ref|
        unless @resource.catalog.resource(ref.to_s)
          description = self.class.direction == :in ? "dependency" : "dependent"
          fail "Could not find #{description} #{ref} for #{resource.ref}"
        end
      end
    end

    # Create edges from each of our relationships.    :in
    # relationships are specified by the event-receivers, and :out
    # relationships are specified by the event generator.  This
    # way 'source' and 'target' are consistent terms in both edges
    # and events -- that is, an event targets edges whose source matches
    # the event's source.  The direction of the relationship determines
    # which resource is applied first and which resource is considered
    # to be the event generator.
    def to_edges
      @value.collect do |reference|
        reference.catalog = resource.catalog

        # Either of the two retrieval attempts could have returned
        # nil.
        unless related_resource = reference.resolve
          self.fail "Could not retrieve dependency '#{reference}' of #{@resource.ref}"
        end

        # Are we requiring them, or vice versa?  See the method docs
        # for futher info on this.
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
          self.debug("subscribes to #{related_resource.ref}")
        else
          # If there's no callback, there's no point in even adding
          # a label.
          subargs = nil
          self.debug("requires #{related_resource.ref}")
        end

        rel = Puppet::Relationship.new(source, target, subargs)
      end
    end
  end

  def self.relationship_params
    RelationshipMetaparam.subclasses
  end


  # Note that the order in which the relationships params is defined
  # matters.  The labelled params (notify and subcribe) must be later,
  # so that if both params are used, those ones win.  It's a hackish
  # solution, but it works.

  newmetaparam(:require, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :NONE}) do
    desc "References to one or more objects that this object depends on.
      This is used purely for guaranteeing that changes to required objects
      happen before the dependent object.  For instance:

          # Create the destination directory before you copy things down
          file { \"/usr/local/scripts\":
            ensure => directory
          }

          file { \"/usr/local/scripts/myscript\":
            source  => \"puppet://server/module/myscript\",
            mode    => 755,
            require => File[\"/usr/local/scripts\"]
          }

      Multiple dependencies can be specified by providing a comma-separated list
      of resources, enclosed in square brackets:

          require => [ File[\"/usr/local\"], File[\"/usr/local/scripts\"] ]

      Note that Puppet will autorequire everything that it can, and
      there are hooks in place so that it's easy for resources to add new
      ways to autorequire objects, so if you think Puppet could be
      smarter here, let us know.

      In fact, the above code was redundant --- Puppet will autorequire
      any parent directories that are being managed; it will
      automatically realize that the parent directory should be created
      before the script is pulled down.

      Currently, exec resources will autorequire their CWD (if it is
      specified) plus any fully qualified paths that appear in the
      command.   For instance, if you had an `exec` command that ran
      the `myscript` mentioned above, the above code that pulls the
      file down would be automatically listed as a requirement to the
      `exec` code, so that you would always be running againts the
      most recent version.
      "
  end

  newmetaparam(:subscribe, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :ALL_EVENTS, :callback => :refresh}) do
    desc "References to one or more objects that this object depends on. This
      metaparameter creates a dependency relationship like **require,**
      and also causes the dependent object to be refreshed when the
      subscribed object is changed. For instance:

          class nagios {
            file { 'nagconf':
              path   => \"/etc/nagios/nagios.conf\"
              source => \"puppet://server/module/nagios.conf\",
            }
            service { 'nagios':
              ensure    => running,
              subscribe => File['nagconf']
            }
          }

      Currently the `exec`, `mount` and `service` types support
      refreshing.
      "
  end

  newmetaparam(:before, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :NONE}) do
    desc %{References to one or more objects that depend on this object. This
      parameter is the opposite of **require** --- it guarantees that
      the specified object is applied later than the specifying object:

          file { "/var/nagios/configuration":
            source  => "...",
            recurse => true,
            before  => Exec["nagios-rebuid"]
          }

          exec { "nagios-rebuild":
            command => "/usr/bin/make",
            cwd     => "/var/nagios/configuration"
          }

      This will make sure all of the files are up to date before the
      make command is run.}
  end

  newmetaparam(:notify, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :ALL_EVENTS, :callback => :refresh}) do
    desc %{References to one or more objects that depend on this object. This
    parameter is the opposite of **subscribe** --- it creates a
    dependency relationship like **before,** and also causes the
    dependent object(s) to be refreshed when this object is changed. For
    instance:

          file { "/etc/sshd_config":
            source => "....",
            notify => Service['sshd']
          }

          service { 'sshd':
            ensure => running
          }

      This will restart the sshd service if the sshd config file changes.}
  end

  newmetaparam(:stage) do
    desc %{Which run stage a given resource should reside in.  This just creates
      a dependency on or from the named milestone.  For instance, saying that
      this is in the 'bootstrap' stage creates a dependency on the 'bootstrap'
      milestone.

      By default, all classes get directly added to the
      'main' stage.  You can create new stages as resources:

          stage { ['pre', 'post']: }

      To order stages, use standard relationships:

          stage { 'pre': before => Stage['main'] }

      Or use the new relationship syntax:

          Stage['pre'] -> Stage['main'] -> Stage['post']

      Then use the new class parameters to specify a stage:

          class { 'foo': stage => 'pre' }

      Stages can only be set on classes, not individual resources.  This will
      fail:

          file { '/foo': stage => 'pre', ensure => file }
    }
  end

  ###############################
  # All of the provider plumbing for the resource types.
  require 'puppet/provider'
  require 'puppet/util/provider_features'

  # Add the feature handling module.
  extend Puppet::Util::ProviderFeatures

  attr_reader :provider

  # the Type class attribute accessors
  class << self
    attr_accessor :providerloader
    attr_writer :defaultprovider
  end

  # Find the default provider.
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

  def self.provider_hash_by_type(type)
    @provider_hashes ||= {}
    @provider_hashes[type] ||= {}
  end

  def self.provider_hash
    Puppet::Type.provider_hash_by_type(self.name)
  end

  # Retrieve a provider by name.
  def self.provider(name)
    name = name.intern

    # If we don't have it yet, try loading it.
    @providerloader.load(name) unless provider_hash.has_key?(name)
    provider_hash[name]
  end

  # Just list all of the providers.
  def self.providers
    provider_hash.keys
  end

  def self.validprovider?(name)
    name = name.intern

    (provider_hash.has_key?(name) && provider_hash[name].suitable?)
  end

  # Create a new provider of a type.  This method must be called
  # directly on the type that it's implementing.
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

  # Make sure we have a :provider parameter defined.  Only gets called if there
  # are providers.
  def self.providify
    return if parameter(:provider)

    newparam(:provider) do
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
        attr_accessor :parenttype
      end

      # We need to add documentation for each provider.
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

      defaultto {
        prov = @resource.class.defaultprovider
        prov.name if prov
      }

      validate do |provider_class|
        provider_class = provider_class[0] if provider_class.is_a? Array
        provider_class = provider_class.class.name if provider_class.is_a?(Puppet::Provider)

        unless provider = @resource.class.provider(provider_class)
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
    end.parenttype = self
  end

  def self.unprovide(name)
    if @defaultprovider and @defaultprovider.name == name
      @defaultprovider = nil
    end

    rmclass(name, :hash => provider_hash, :prefix => "Provider")
  end

  # Return an array of all of the suitable providers.
  def self.suitableprovider
    providerloader.loadall if provider_hash.empty?
    provider_hash.find_all { |name, provider|
      provider.suitable?
    }.collect { |name, provider|
      provider
    }.reject { |p| p.name == :fake } # For testing
  end

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

  # Specify a block for generating a list of objects to autorequire.  This
  # makes it so that you don't have to manually specify things that you clearly
  # require.
  def self.autorequire(name, &block)
    @autorequires ||= {}
    @autorequires[name] = block
  end

  # Yield each of those autorequires in turn, yo.
  def self.eachautorequire
    @autorequires ||= {}
    @autorequires.each { |type, block|
      yield(type, block)
    }
  end

  # Figure out of there are any objects we can automatically add as
  # dependencies.
  def autorequire(rel_catalog = nil)
    rel_catalog ||= catalog
    raise(Puppet::DevError, "You cannot add relationships without a catalog") unless rel_catalog

    reqs = []
    self.class.eachautorequire { |type, block|
      # Ignore any types we can't find, although that would be a bit odd.
      next unless typeobj = Puppet::Type.type(type)

      # Retrieve the list of names from the block.
      next unless list = self.instance_eval(&block)
      list = [list] unless list.is_a?(Array)

      # Collect the current prereqs
      list.each { |dep|
        # Support them passing objects directly, to save some effort.
        unless dep.is_a? Puppet::Type
          # Skip autorequires that we aren't managing
          unless dep = rel_catalog.resource(type, dep)
            next
          end
        end

        reqs << Puppet::Relationship.new(dep, self)
      }
    }

    reqs
  end

  # Build the dependencies associated with an individual object.
  def builddepends
    # Handle the requires
    self.class.relationship_params.collect do |klass|
      if param = @parameters[klass.name]
        param.to_edges
      end
    end.flatten.reject { |r| r.nil? }
  end

  # Define the initial list of tags.
  def tags=(list)
    tag(self.class.name)
    tag(*list)
  end

  # Types (which map to resources in the languages) are entirely composed of
  # attribute value pairs.  Generally, Puppet calls any of these things an
  # 'attribute', but these attributes always take one of three specific
  # forms:  parameters, metaparams, or properties.

  # In naming methods, I have tried to consistently name the method so
  # that it is clear whether it operates on all attributes (thus has 'attr' in
  # the method name, or whether it operates on a specific type of attributes.
  attr_writer :title
  attr_writer :noop

  include Enumerable

  # class methods dealing with Type management

  public

  # the Type class attribute accessors
  class << self
    attr_reader :name
    attr_accessor :self_refresh
    include Enumerable, Puppet::Util::ClassGen

    include Puppet::Util
    include Puppet::Util::Logging
  end

  # all of the variables that must be initialized for each subclass
  def self.initvars
    @doc ||= ""
  end

  def self.to_s
    if defined?(@name)
      "Puppet::Type::#{@name.to_s.capitalize}"
    else
      super
    end
  end

  # Create a block to validate that our object is set up entirely.  This will
  # be run before the object is operated on.
  def self.validate(&block)
    define_method(:validate, &block)
    #@validate = block
  end

  # Origin information.
  attr_accessor :file, :line

  # The catalog that this resource is stored in.
  attr_accessor :catalog

  # is the resource exported
  attr_accessor :exported

  # is the resource virtual (it should not :-))
  attr_accessor :virtual

  # create a log at specified level
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

  attr_reader :original_parameters

  # initialize the type instance
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

    self.validate if self.respond_to?(:validate)
  end

  private

  # Set our resource's name.
  def set_name(hash)
    self[name_var] = hash.delete(name_var) if name_var
  end

  # Set all of the parameters from a hash, in the appropriate order.
  def set_parameters(hash)
    # Use the order provided by allattrs, but add in any
    # extra attributes from the resource so we get failures
    # on invalid attributes.
    no_values = []
    order = (self.class.parameter_names + hash.keys).uniq
    order.uniq.each do |attr|
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

  # Set up all of our autorequires.
  def finish
    # Make sure all of our relationships are valid.  Again, must be done
    # when the entire catalog is instantiated.
    self.class.relationship_params.collect do |klass|
      if param = @parameters[klass.name]
        param.validate_relationship
      end
    end.flatten.reject { |r| r.nil? }
  end

  # For now, leave the 'name' method functioning like it used to.  Once 'title'
  # works everywhere, I'll switch it.
  def name
    self[:name]
  end

  # Look up our parent in the catalog, if we have one.
  def parent
    return nil unless catalog

    unless defined?(@parent)
      if parents = catalog.adjacent(self, :direction => :in)
        # We should never have more than one parent, so let's just ignore
        # it if we happen to.
        @parent = parents.shift
      else
        @parent = nil
      end
    end
    @parent
  end

  # Return the "type[name]" style reference.
  def ref
    # memoizing this is worthwhile ~ 3 percent of calls are the "first time
    # around" in an average run of Puppet. --daniel 2012-07-17
    @ref ||= "#{self.class.name.to_s.capitalize}[#{self.title}]"
  end

  def self_refresh?
    self.class.self_refresh
  end

  # Mark that we're purging.
  def purging
    @purging = true
  end

  # Is this resource being purged?  Used by transactions to forbid
  # deletion when there are dependencies.
  def purging?
    if defined?(@purging)
      @purging
    else
      false
    end
  end

  # Retrieve the title of an object.  If no title was set separately,
  # then use the object's name.
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

  # convert to a string
  def to_s
    self.ref
  end

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

  def virtual?;  !!@virtual;  end
  def exported?; !!@exported; end

  def appliable_to_device?
    self.class.can_apply_to(:device)
  end

  def appliable_to_host?
    self.class.can_apply_to(:host)
  end
end
end

require 'puppet/provider'

# Always load these types.
Puppet::Type.type(:component)
