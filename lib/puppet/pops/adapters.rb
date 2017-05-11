# The Adapters module contains adapters for Documentation, Origin, SourcePosition, and Loader.
#
module Puppet::Pops
module Adapters
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
