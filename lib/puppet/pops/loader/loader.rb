# Loader
# ===
# A Loader is responsible for loading "entities" ("instantiable and executable objects in the puppet language" which
# are type, hostclass, definition, function, and bindings.
#
# The main method for users of a Loader is the `load` or `load_typed methods`, which returns a previously loaded entity
# of a given type/name, and searches and loads the entity if not already loaded.
#
# private entities
# ---
# TODO: handle loading of entities that are private. Suggest that all calls pass an origin_loader (the loader
# where request originated (or symbol :public). A module loader has one (or possibly a list) of what is
# considered to represent private loader - i.e. the dependency loader for a module. If an entity is private
# it should be stored with this status, and an error should be raised if the origin_loader is not on the list
# of accepted "private" loaders.
# The private loaders can not be given at creation time (they are parented by the loader in question). Another
# alternative is to check if the origin_loader is a child loader, but this requires bidirectional links
# between loaders or a search if loader with private entity is a parent of the origin_loader).
#
# @api public
#
class Puppet::Pops::Loader::Loader

  # Describes the kinds of things that loaders can load
  LOADABLE_KINDS = [:func_4x, :func_4xpp, :type_pp].freeze

  # Produces the value associated with the given name if already loaded, or available for loading
  # by this loader, one of its parents, or other loaders visible to this loader.
  # This is the method an external party should use to "get" the named element.
  #
  # An implementor of this method should first check if the given name is already loaded by self, or a parent
  # loader, and if so return that result. If not, it should call `find` to perform the loading.
  #
  # @param type [:Symbol] the type to load
  # @param name [String, Symbol]  the name of the entity to load
  # @return [Object, nil] the value or nil if not found
  #
  # @api public
  #
  def load(type, name)
    if result = load_typed(TypedName.new(type, name.to_s))
      result.value
    end
  end

  # Loads the given typed name, and returns a NamedEntry if found, else returns nil.
  # This the same a `load`, but returns a NamedEntry with origin/value information.
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  # @return [NamedEntry, nil] the entry containing the loaded value, or nil if not found
  #
  # @api public
  #
  def load_typed(typed_name)
    raise NotImplementedError.new
  end

  # Returns an already loaded entry if one exists, or nil. This does not trigger loading
  # of the given type/name.
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  # @param check_dependencies [Boolean] - if dependencies should be checked in additiona to here and parent
  # @return [NamedEntry, nil] the entry containing the loaded value, or nil if not found
  # @api public
  #
  def loaded_entry(typed_name, check_dependencies = false)
    raise NotImplementedError.new(self.class)
  end

  # Produces the value associated with the given name if defined **in this loader**, or nil if not defined.
  # This lookup does not trigger any loading, or search of the given name.
  # An implementor of this method may not search or look up in any other loader, and it may not
  # define the name.
  #
  # @param typed_name [TypedName] - the type, name combination to lookup
  #
  # @api private
  #
  def [] (typed_name)
    if found = get_entry(typed_name)
      found.value
    else
      nil
    end
  end

  # Searches for the given name in this loader's context (parents should already have searched their context(s) without
  # producing a result when this method is called).
  # An implementation of find typically caches the result.
  #
  # @param typed_name [TypedName] the type, name combination to lookup
  # @return [NamedEntry, nil] the entry for the loaded entry, or nil if not found
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

  # Produces the private loader for loaders that have a one (the visibility given to loaded entities).
  # For loaders that does not provide a private loader, self is returned.
  #
  # @api private
  def private_loader
    self
  end

  # Binds a value to a name. The name should not start with '::', but may contain multiple segments.
  #
  # @param type [:Symbol] the type of the entity being set
  # @param name [String, Symbol] the name of the entity being set
  # @param origin [URI, #uri, String] the origin of the set entity, a URI, or provider of URI, or URI in string form
  # @return [NamedEntry, nil] the created entry
  #
  # @api private
  #
  def set_entry(type, name, value, origin = nil)
    raise NotImplementedError.new
  end

  # Produces a NamedEntry if a value is bound to the given name, or nil if nothing is bound.
  #
  # @param typed_name [TypedName] the type, name combination to lookup
  # @return [NamedEntry, nil] the value bound in an entry
  #
  # @api private
  #
  def get_entry(typed_name)
    raise NotImplementedError.new
  end

  # A loader is by default a loader for all kinds of loadables. An implementation may override
  # if it cannot load all kinds.
  #
  # @api private
  def loadables
    LOADABLE_KINDS
  end

  # An entry for one entity loaded by the loader.
  #
  class NamedEntry
    attr_reader :typed_name
    attr_reader :value
    attr_reader :origin

    def initialize(typed_name, value, origin)
      @typed_name = typed_name
      @value = value
      @origin = origin
      freeze()
    end
  end

  # A name/type combination that can be used as a compound hash key
  #
  class TypedName
    DOUBLE_COLON = '::'

    attr_reader :hash
    attr_reader :type
    attr_reader :name
    attr_reader :name_parts
    attr_reader :compound_name

    def initialize(type, name)
      @type = type
      # relativize the name (get rid of leading ::), and make the split string available
      parts = name.to_s.split(DOUBLE_COLON)
      if parts[0].empty?
        parts.shift
        @name = name[2..-1]
      else
        @name = name
      end
      @name_parts = parts

      # Use a frozen compound key for the hash and comparison
      @compound_name = "#{type}/#{name}".freeze
      @hash = @compound_name.hash
      freeze
    end

    def ==(o)
      o.class == self.class && o.compound_name == @compound_name
    end

    alias eql? ==

    def qualified?
      @name_parts.size > 1
    end

    def to_s
      @compound_name
    end
  end
end

