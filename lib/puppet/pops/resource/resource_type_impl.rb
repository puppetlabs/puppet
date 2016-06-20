require 'puppet/pops/resource/param'
module Puppet::Pops
module Resource

class ResourceTypeImpl
  # Make instances of this class directly createable from the Puppet Language
  # as object.
  #
  include Puppet::Pops::Types::PuppetObject

  # Instances of ResourceTypeImpl can be used as the type of a Puppet::Parser::Resource/Puppet::Resource when compiling
  #
  include Puppet::CompilableResourceType

  # Returns the Puppet Type for this instance.
  def self._ptype
    # todo - should return an instance of PObjectType.
  end

  # Compares this type against the given _other_ (type) and returns -1, 0, or +1 depending on the order.
  # @param other [Object] the object to compare against (produces nil, if not kind of Type}
  # @return [-1, 0, +1, nil] produces -1 if this type is before the given _other_ type, 0 if equals, and 1 if after.
  #   Returns nil, if the given _other_ is not a kind of Type.
  # @see Comparable
  #
  def <=>(other)
    # Order is only maintained against other types, not arbitrary objects.
    # The natural order is based on the reference name used when comparing
    return nil unless other.is_a?(Puppet::CompilableResourceType)
    # against other type instances.
    self.ref <=> other.ref
  end


  # Mocking - an imaginary loaded 'notify'
  def self.notify_cheat()
    new(
      'notify',
      [],          # prop
      [Param.new(String, 'message')] # param
      )
  end

  METAPARAMS = [
    :noop,
    :schedule,
    :audit,
    :loglevel,
    :alias,
    :tag,
    :require,
    :subscribe,
    :before,
    :notify,
    :stage,
    :export,
    :consume
    ].freeze

  # Speed up lookup
  METAPARAMSET = Set.new(METAPARAMS).freeze

  attr_reader :name
  attr_reader :properties
  attr_reader :parameters
  attr_reader :title_patterns
  attr_reader :isomorphic

  def initialize(name, properties, parameters, title_patterns = nil, isomorphic = true)
    @name = name
    @properties = properties
    @parameters = parameters
    @title_patterns = title_patterns
    @isomorphic = isomorphic

    # Compute attributes hash
    # Compute key_names (possibly compound key if there are multiple name vars).
    @attributes = {}
    @key_attributes = []

    # Name to kind of attribute
    @attr_types = {}

    # Add all meta params
    METAPARAMS.each {|p| @attr_types[p] = :meta }

    # Compute the set of property names (claimed to be used millions of times
    # But may only by at apply time
    @property_set = Set.new(properties.map do |p|
      symname = p.name.to_sym
      @attributes[symname] = p
      @key_attributes << symname if p.name_var
      @attr_types[symname] = :property
      symname
    end).freeze

    # Compute the set of parameter names (claimed to be used millions of times
    # But may only by at apply time
    @param_set = Set.new(parameters.map do |p|
      symname = p.name.to_sym
      @attributes[symname] = p
      @key_attributes << symname if p.name_var
      @attr_types[symname] = :param
      symname
    end).freeze
  end

  # Override CompilableResource inclusion
  def is_3x_ruby_plugin?
    false
  end

  # Answers if the parameter name is a parameter/attribute of this type
  # This is part of the Puppet::Type API
  # Check if used when compiling (it is triggered in an apply)
  #
  def valid_parameter?(name)
    @attributes.include?(name) || METAPARAMSET.include?(name)
  end

  # The type implementation of finish does a lot of things
  # * iterates over all parameters and calls post_compile on them if the parameter impl responds to post_compile
  # * validates the relationship parameters
  #
  # This implementation does nothing - it is assumed that the catalog is already validated
  # via the relationship validator (done late in the game).
  def finish()
    # Do nothing.
  end

  # This is called on a resource type
  # it performs tagging if it is a Class or Node.
  # It also ensure the parent type is in the catalog, but that is weird since
  # resource types cannot really inherit
  def instantiate_resource(scope, resource)
    # Do nothing because nothing is needed when compiling.

    # This is what the Puppet::Type implementation does
    # None of this should be needed

      #    # Make sure our parent class has been evaluated, if we have one.
      #    if parent && !scope.catalog.resource(resource.type, parent)
      #      parent_type(scope).ensure_in_catalog(scope)
      #    end

    # This will never happen

      #    if ['Class', 'Node'].include? resource.type
      #      scope.catalog.tag(*resource.tags)
      #    end
  end

  # Being isomorphic in puppet means that the resource is managing a state
  # (as opposed to a resource like Exec that is a function, possibly with side effect.
  # In a Ruby implementation of a resource type, @isomorphic = false is used to turn
  # off isomorphism, it is true by default.
  # This is part of the Puppet::Type API.
  #
  def isomorphic?
    @isomorphic
  end

  # Produces the names of the attributes that make out the unique id of a resource
  #
  def key_attributes
    @key_attributes
  end

  # Gives a type a chance to issue deprecations for parameters.
  # @param title [String] the title of the resource of this type
  # @param attributes [Array<Param>] the set parameters in the resource instance
  def deprecate_params(title, attributes)
    # TODO: Current API somewhat unclear, if done at type level, or per
    #       Param.
  end

  #######################
  # UNSUPPORTED STUFF
  #######################

  # Applications are not supported
  def application?
    false
  end

  ############################
  # DON'T KNOW YET
  ############################


  ##################################################
  # NEVER CALLED COMPILE SIDE FOR A COMPILATION
  ##################################################

  # Answers :property, :param or :meta depending on the type of the attribute
  # According to original version, this is called millions of times
  # and a cache is required. 
  # @param name [Symbol]
  def attrtype(name)
    raise NotImplementedError, "attrtype() - returns the kind (:meta, :param, or :property) of the parameter"
    # @attr_types[name]
  end

  # Returns the implementation of a param/property/attribute - i.e. a Param class
  def attrclass(name)
    raise NotImplementedError, "attrclass() - returns the (param) class of the parameter"
  end

  # PROBABLY NOT USED WHEN COMPILING
  # Returns the names of all attributes in a defined order:
  # * all key attributes (the composite id)
  # * :provider if it is specified
  # * all properties
  # * all parameters
  # * meta parameters
  #
  def allattrs
    raise NotImplementedError, "allattrs() - return all attribute names in order - probably not used master side"
    # key_attributes | (parameters & [:provider]) | properties.collect { |property| property.name } | parameters | metaparams
  end

  # Sets "applies to host"
  def apply_to
    raise NotImplementedError, "apply_to() - probably used when selecting a provider (device/host support)"
  end

  def apply_to_host
    raise NotImplementedError, "apply_to_host() - probably used when selecting a provider (device/host support)"
  end

  def apply_to_device
    raise NotImplementedError, "apply_to_device() - probably used when selecting a provider (device/host support)"
  end

  def apply_to_all
    raise NotImplementedError, "apply_to_all() - probably used when selecting a provider (device/host support)"
  end

  def can_apply_to_target(target)
    raise NotImplementedError, "can_apply_to_target() - probably used when selecting a provider (device/host support)"
  end

end
end
end
