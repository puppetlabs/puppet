# A loader is responsible for loading "types" (actually
# "instantiable and executable objects in the puppet language" which
# are type, hostclass, definition and function.
#
# The main method for users of a loader is the `load` method, which returns a previously loaded entity
# of a given type/name, and searches and loads the entity if not already loaded.
#
# @api public
#
class Puppet::Pops::Loader

  # Produces the value associated with the given name if already loaded, or available for loading
  # by this loader, one of its parents, or other loaders visible to this loader.
  # This is the method an external party should use to "get" the named element.
  #
  # An implementor of this method should first check if the given name is already loaded by self, or a parent
  # loader, and if so return that result. If not, it should call #find to perform the loading.
  #
  # @param type [:Symbol] - the type to load
  # @param name [String, Symbol] - the name of the entity to load
  #
  # @api public
  #
  def load(type, name)
    load_typed(TypedName.new(type, name))
  end

  # The same as load, but acts on a type/name combination.
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  #
  # @api public
  #
  def load_typed(typed_name)
    raise NotImplementedError.new
  end

  # Produces the value associated with the given name if defined in this loader, or nil if not defined.
  # This lookup does not trigger any loading, or search of the given name.
  # An implementor of this method may not search or look up in any other loader, and it may not
  # define the name.
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  #
  # @api private
  #
  def [] (typed_name)
    raise NotImplementedError.new
  end

  # Searches for the given name in this loaders context (parents have already searched their context(s) without
  # producing a result when this method is called).
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  #
  # @api private
  #
  def find(typed_name)
    raise NotImplementedError.new
  end

  # Returns the parent of the loader, or nil, if this is the top most loader. This implementation returns nil.
  def parent
    nil
  end

  # Binds a value to a name. The name should not start with '::', but may contain multiple segments.
  #
  # @param type [:Symbol] - the type of the entity being set
  # @param name [String, Symbol] - the name of the entity being set
  # @param origin [URI, #uri, String] - the origin of the set entity, a URI, or provider of URI, or URI in string form
  #
  # @api private
  #
  def set_entry(type, name, value, origin = nil)
    raise NotImplementedError.new
  end

  # Produces a NamedEntry if a value is bound to the given name, or nil if nothing is bound.
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  #
  # @api private
  #
  def get_entry(typed_name)
    raise NotImplementedError.new
  end

  # An entry for one entity loaded by the loader.
  #
  class NamedEntry
    attr_reader :status
    attr_reader :typed_name
    attr_reader :value
    attr_reader :origin

    def initialize(status, typed_name, value, origin)
      @status = status
      @name = typed_name
      @value = value
      @origin = origin
      freeze()
    end
  end

  # A name/type combination that can be used as a compound hash key
  #
  class TypedName
    attr_reader :type
    attr_reader :name
    def initialize(type, name)
      @type = type
      @name = Puppet::Pops::Utils.relativize_name(name)

      # Not allowed to have numeric names - 0, 010, 0x10, 1.2 etc
      if Puppet::Pops::Utils.is_numeric?(@name)
        raise ArgumentError, "Illegal attempt to use a numeric name '#{name}' at #{origin_label(origin)}."
      end

      freeze()
    end

    def hash
      [self.class, type, name]
    end

    def ==(o)
      o.class == self.class && type == o.type && name == o.name
    end

    alias eql? ==

    def to_s
      "#{type}/#{name}"
    end
  end
end

