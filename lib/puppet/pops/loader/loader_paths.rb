
# LoaderPaths
# ===
# The central loader knowledge about paths, what they represent and how to instantiate from them.
# Contains helpers (*smart paths*) to deal with lazy resolution of paths.
#
# TODO: Currently only supports loading of functions (3 kinds)
#
module Puppet::Pops::Loader::LoaderPaths
  # Returns an array of SmartPath, each instantiated with a reference to the given loader (for root path resolution
  # and existence checks). The smart paths in the array appear in precedence order. The returned array may be
  # mutated.
  #
  def self.relative_paths_for_type(type, loader)
    result =
    case type
    when :function
        [FunctionPath4x.new(loader)]
    else
      # unknown types, simply produce an empty result; no paths to check, nothing to find... move along...
      []
    end
    result
  end

#  # DO NOT REMOVE YET. needed later? when there is the need to decamel a classname
#  def de_camel(fq_name)
#    fq_name.to_s.gsub(/::/, '/').
#    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
#    gsub(/([a-z\d])([A-Z])/,'\1_\2').
#    tr("-", "_").
#    downcase
#  end

  class SmartPath
    # Generic path, in the sense of "if there are any entities of this kind to load, where are they?"
    attr_reader :generic_path

    # Creates SmartPath for the given loader (loader knows how to check for existence etc.)
    def initialize(loader)
      @loader = loader
    end

    def generic_path()
      return @generic_path unless @generic_path.nil?

      root_path = @loader.path
      @generic_path = (root_path.nil? ? relative_path : File.join(root_path, relative_path))
    end

    # Effective path is the generic path + the name part(s) + extension.
    #
    def effective_path(typed_name, start_index_in_name)
      "#{File.join(generic_path, typed_name.name_parts)}#{extension}"
    end

    def relative_path()
      raise NotImplementedError.new
    end

    def instantiator()
      raise NotImplementedError.new
    end
  end

  class RubySmartPath < SmartPath
    def extension
      ".rb"
    end

    # Duplication of extension information, but avoids one call
    def effective_path(typed_name, start_index_in_name)
      "#{File.join(generic_path, typed_name.name_parts)}.rb"
    end
  end

  class FunctionPath4x < RubySmartPath
    FUNCTION_PATH_4X = File.join('puppet', 'functions')

    def relative_path
      FUNCTION_PATH_4X
    end

    def instantiator()
      Puppet::Pops::Loader::RubyFunctionInstantiator
    end
  end

  # SmartPaths
  # ===
  # Holds effective SmartPath instances per type
  #
  class SmartPaths
    def initialize(path_based_loader)
      @loader = path_based_loader
      @smart_paths = {}
    end

    # Ensures that the paths for the type have been probed and pruned to what is existing relative to
    # the given root.
    #
    # @param type [Symbol] the entity type to load
    # @return [Array<SmartPath>] array of effective paths for type (may be empty)
    #
    def effective_paths(type)
      smart_paths = @smart_paths
      loader = @loader
      unless effective_paths = smart_paths[type]
        # type not yet processed, does the various directories for the type exist ?
        # Get the relative dirs for the type
        paths_for_type = Puppet::Pops::Loader::LoaderPaths.relative_paths_for_type(type, loader)
        # Check which directories exist in the loader's content/index
        effective_paths = smart_paths[type] = paths_for_type.select { |sp| loader.meaningful_to_search?(sp) }
      end
      effective_paths
    end
  end
end
