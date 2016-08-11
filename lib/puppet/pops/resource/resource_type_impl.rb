require_relative 'param'

module Puppet::Pops
module Resource

def self.register_ptypes(loader, ir)
  types = [Param, ResourceTypeImpl].map do |c|
    c.register_ptype(loader, ir)
  end
  types.each {|t| t.resolve(Types::TypeParser.singleton, loader) }
end

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
    @ptype
  end

  def self.register_ptype(loader, ir)
    param_ref = Types::PTypeReferenceType.new('Puppet::Resource::Param')
    @ptype = Pcore::create_object_type(loader, ir, self, 'Puppet::Resource::ResourceType3', nil,
      {
        Types::KEY_NAME => Types::PStringType::NON_EMPTY,
        'properties' => {
          Types::KEY_TYPE => Types::PArrayType.new(param_ref),
          Types::KEY_VALUE => EMPTY_ARRAY
        },
        'parameters' => {
          Types::KEY_TYPE => Types::PArrayType.new(param_ref),
          Types::KEY_VALUE => EMPTY_ARRAY
        },
        'title_patterns_hash' => {
          Types::KEY_TYPE => Types::POptionalType.new(
            Types::PHashType.new(Types::PRegexpType::DEFAULT, Types::PArrayType.new(Types::PStringType::NON_EMPTY))),
          Types::KEY_VALUE => nil
        },
        'isomorphic' => {
          Types::KEY_TYPE => Types::PBooleanType::DEFAULT,
          Types::KEY_VALUE => true
        },
      },
      EMPTY_HASH,
      [Types::KEY_NAME]
    )
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
  attr_reader :title_patterns_hash
  attr_reader :title_patterns
  attr_reader :isomorphic

  def initialize(name, properties = EMPTY_ARRAY, parameters = EMPTY_ARRAY, title_patterns_hash = nil, isomorphic = true)
    @name = name
    @properties = properties
    @parameters = parameters
    @title_patterns_hash = title_patterns_hash
    @isomorphic = isomorphic

    # Compute attributes hash
    # Compute key_names (possibly compound key if there are multiple name vars).
    @attributes = {}
    @key_attributes = []

    # Name to kind of attribute
    @attr_types = {}

    # Add all meta params
    METAPARAMS.each {|p| @attr_types[p] = :meta }

    @property_set = Set.new(properties.map do |p|
      symname = p.name.to_sym
      @attributes[symname] = p
      @key_attributes << symname if p.name_var
      @attr_types[symname] = :property
      symname
    end).freeze

    @param_set = Set.new(parameters.map do |p|
      symname = p.name.to_sym
      @attributes[symname] = p
      @key_attributes << symname if p.name_var
      @attr_types[symname] = :param
      symname
    end).freeze

    # API for title patterns is [ [regexp, [ [ [sym, <lambda>], [sym, <lambda>] ] ] ] ]
    # Where lambdas are optional. This resource type impl does not support lambdas
    # Note that the pcore file has a simpler hashmap that is post processed here
    # since the structure must have Symbol instances for names which the .pp representation
    # does not deliver.
    #
    @title_patterns =
      case @key_attributes.length
      when 0
        # TechDebt: The case of specifying title patterns when having no name vars is unspecified behavior in puppet
        # Here it is silently ignored.
        []
      when 1
        if @title_pattners_hash.nil?
          [ [ /(.*)/m, [ [@key_attributes.first] ] ] ]
        else
          # TechDebt: The case of having one namevar and an empty title patterns is unspecified behavior in puppet.
          # Here, it may lead to an empty map which may or may not trigger the wanted/expected behavior.
          #
          @title_patterns_hash.map {|k,v| [ k, [ v.map {|n| n.to_sym } ] ] }
        end
      else
        if @title_patterns_hash.nil? || @title_patterns_hash.empty?
          # TechDebt: While title patterns must be specified when more than one is used, they do not have
          # to match/set them all since some namevars can be omitted (to support the use case in
          # the 'package' type where 'provider' attribute is handled as part of the key without being
          # set from the title.
          #
          raise Puppet::DevError,"you must specify title patterns when there are two or more key attributes"
        end
        @title_patterns_hash.nil? ? [] : @title_patterns_hash.map {|k,v| [ k, [ v.map {|n| n.to_sym } ] ] }
      end
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
