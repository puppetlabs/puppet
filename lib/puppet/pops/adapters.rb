# The Adapters module contains adapters for Documentation, Origin, SourcePosition, and Loader.
#
module Puppet::Pops
module Adapters

  class ObjectIdCacheAdapter < Puppet::Pops::Adaptable::Adapter
    attr_reader :cache

    def initialize
      @cache = {}
    end

    # Retrieves a mutable hash with all stored values
    def retrieve(cache_id)
      @cache[cache_id.__id__] ||= {}
    end

    # Adds a value to the cache for a given cache_id and key unless the value is already set.
    # If not already set, the given block is called to produce the value.
    # @param cache_id [Object] an object acting as cache identifier
    # @param key [Object] the key for an entry in the cache
    # @yield [] calls the block without parameters to produce the value for the key unless key already bound
    # @api public
    # 
    def add(cache_id, key, &block)
      the_cache = retrieve(cache_id)
      val = the_cache[key]
      if val.nil? && !the_cache.has_key?(key)
        val = the_cache[key] = yield
      end
      val
    end

    # Inserts a value for key into the cache identified by the given cache_id overwriting any
    # earlier value stored in the cache for that key. If the stored value needs some kind of
    # "close" operation that must have already been taken care of by the caller.
    # @api public
    #
    def insert(cache_id, key, value)
      retrieve(cache_id)[key] = value
    end

    # Gets a value from the cache hash and optionally calls a given block with this value.
    # The given block is only called if the key is bound in the hash.
    #
    # The intended use of this method is to process a cached object that needs some kind
    # of close - for example `adapter.get(self, :connection) {|c| c.close }`
    #
    # @param cache_id [Object] an object acting as cache identifier
    # @param key [Object] the key to get
    # @param block [Proc] an optional block called with the bound value if the key was bound
    # @yield [val] calls a given optional block with the bound value val 
    # @return [Object] the bound value for the key, or nil
    # @api public
    #
    def get(cache_id, key)
      the_cache = retrieve(cache_id)
      val = the_cache[key]
      return val unless block_given?
      if !val.nil? || the_cache.has_key?(key)
        yield(val)
      end
      val
    end

    # Clears the cache for the given cache_id after optionally feeding each key/value pair to a given block.
    # @example close and clear all
    #   adapter.clear(cache_id) {|k, v| v.close }
    #
    # @example simply forget all
    #   adapter.clear(cache_id)
    #
    # @param cache_id [Object] an object acting as cache identifier
    # @yield [k, v] yields each key/value before clearing the cache if a block is given
    # @api public
    #
    def clear(cache_id)
      the_cache = retrieve(cache_id)
      if block_given?
        the_cache.each_pair {|k,v| yield(k,v) }
      end
      @cache.delete(cache_id.__id__)
    end

    # Replaces a value bound to key in the cache identified by cache_id with returned value from the given block.
    # The given block gets a bound value (or nil if nothing was bound). The returned value from the block is bound (it may be
    # the same as the old value).
    # This is useful to replace (close old, create new) or refresh values in the cache.
    #
    # @param cache_id [Object] an object acting as cache identifier
    # @param key [Object] the key to replace
    # @return the value returned by the block (the new value)
    # @yield [bound_value] yields the bound value to the block
    # @api public
    #
    def replace(cache_id, key, &block)
      the_cache = retrieve(cache_id)
      the_cache[key] = yield(the_cache[:key])
    end
  end

  # A documentation adapter adapts an object with a documentation string.
  # (The intended use is for a source text parser to extract documentation and store this
  # in DocumentationAdapter instances).
  #
  class DocumentationAdapter < Adaptable::Adapter
    # @return [String] The documentation associated with an object
    attr_accessor :documentation
  end

  # An  empty alternative adapter is used when there is the need to
  # attach a value to be used if the original is empty. This is used
  # when a lazy evaluation takes place, and the decision how to handle an
  # empty case must be delayed.
  #
  class EmptyAlternativeAdapter < Adaptable::Adapter
    # @return [Object] The alternative value associated with an object
    attr_accessor :empty_alternative
  end

  # This class is for backward compatibility only. It's not really an adapter but it is
  # needed for the puppetlabs-strings gem
  # @deprecated
  class SourcePosAdapter
    def self.adapt(object)
      new(object)
    end

    def initialize(object)
      @object = object
    end

    def file
      @object.file
    end

    def line
      @object.line
    end

    def pos
      @object.pos
    end

    def extract_text
      @object.locator.extract_text(@object.offset, @object.length)
    end
  end

  # A LoaderAdapter adapts an object with a {Loader}. This is used to make further loading from the
  # perspective of the adapted object take place in the perspective of this Loader.
  #
  # It is typically enough to adapt the root of a model as a search is made towards the root of the model
  # until a loader is found, but there is no harm in duplicating this information provided a contained
  # object is adapted with the correct loader.
  #
  # @see Utils#find_adapter
  # @api private
  class LoaderAdapter < Adaptable::Adapter
    attr_accessor :loader_name

    # Finds the loader to use when loading originates from the source position of the given argument.
    #
    # @param instance [Model::PopsObject] The model object
    # @param file [String] the file from where the model was parsed
    # @param default_loader [Loader] the loader to return if no loader is found for the model
    # @return [Loader] the found loader or default_loader if it could not be found
    #
    def self.loader_for_model_object(model, file = nil, default_loader = nil)
      loaders = Puppet.lookup(:loaders) { nil }
      if loaders.nil?
        default_loader || Loaders.static_loader
      else
        loader_name = loader_name_by_source(loaders.environment, model, file)
        if loader_name.nil?
          default_loader || loaders[Loader::ENVIRONMENT_PRIVATE]
        else
          loaders[loader_name]
        end
      end
    end

    class PathsAndNameCacheAdapter < Puppet::Pops::Adaptable::Adapter
      attr_accessor :cache, :paths
    end

    # Attempts to find the module that `instance` originates from by looking at it's {SourcePosAdapter} and
    # compare the `locator.file` found there with the module paths given in the environment found in the
    # given `scope`. If the file is found to be relative to a path, then the first segment of the relative
    # path is interpreted as the name of a module. The object that the {SourcePosAdapter} is adapted to
    # will then be adapted to the private loader for that module and that adapter is returned.
    #
    # The method returns `nil` when no module could be found.
    #
    # @param environment [Puppet::Node::Environment] the current environment
    # @param instance [Model::PopsObject] the AST for the code
    # @param file [String] the path to the file for the code or `nil`
    # @return [String] the name of the loader associated with the source
    # @api private
    def self.loader_name_by_source(environment, instance, file)
      file = instance.file if file.nil?
      return nil if file.nil? || EMPTY_STRING == file
      pn_adapter = PathsAndNameCacheAdapter.adapt(environment) do |a|
        a.paths ||= environment.modulepath.map { |p| Pathname.new(p) }
        a.cache ||= {}
      end
      dir = File.dirname(file)
      pn_adapter.cache.fetch(dir) do |key|
        mod = find_module_for_dir(environment, pn_adapter.paths, dir)
        loader_name = mod.nil? ? nil : "#{mod.name} private"
        pn_adapter.cache[key] = loader_name
      end
    end

    # @api private
    def self.find_module_for_dir(environment, paths, dir)
      return nil if dir.nil?
      file_path = Pathname.new(dir)
      paths.each do |path|
        begin
          relative_path = file_path.relative_path_from(path).to_s.split(File::SEPARATOR)
        rescue ArgumentError
          # file_path was not relative to the module_path. That's OK.
          next
        end
        if relative_path.length > 1
          mod = environment.module(relative_path[0])
          return mod unless mod.nil?
        end
      end
      nil
    end
  end
end
end
