
# LoaderPaths
# ===
# The central loader knowledge about paths, what they represent and how to instantiate from them.
# Contains helpers (*smart paths*) to deal with lazy resolution of paths.
#
# TODO: Currently only supports loading of functions (2 kinds)
#
module Puppet::Pops::Loader::LoaderPaths
  # Returns an array of SmartPath, each instantiated with a reference to the given loader (for root path resolution
  # and existence checks). The smart paths in the array appear in precedence order. The returned array may be
  # mutated.
  #
  def self.relative_paths_for_type(type, loader)
    result = []
    case type
    when :function
        # Only include support for the loadable items the loader states it can contain
        if loader.loadables.include?(:func_4x)
          result << FunctionPath4x.new(loader)
        end
        if loader.loadables.include?(:func_4xpp)
          result << FunctionPathPP.new(loader)
        end
        # When wanted also add FunctionPath3x to load 3x functions
    when :type
      result << TypePathPP.new(loader) if loader.loadables.include?(:type_pp)
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

      the_root_path = root_path() # @loader.path
      @generic_path = (the_root_path.nil? ? relative_path : File.join(the_root_path, relative_path))
    end

    def root_path
      @loader.path
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
    EXTENSION = '.rb'.freeze

    def extension
      EXTENSION
    end

    # Duplication of extension information, but avoids one call
    def effective_path(typed_name, start_index_in_name)
      "#{File.join(generic_path, typed_name.name_parts)}.rb"
    end
  end

  # A PuppetSmartPath is rooted at the loader's directory one level up from what the loader specifies as it
  # path (which is a reference to its 'lib' directory.
  #
  class PuppetSmartPath < SmartPath
    EXTENSION = '.pp'.freeze

    def extension
      EXTENSION
    end

    def root_path
      # Drop the lib part (it may not exist and cannot be navigated to in a relative way)
      Puppet::FileSystem.dir_string(@loader.path)
    end

    # Duplication of extension information, but avoids one call
    def effective_path(typed_name, start_index_in_name)
      # Puppet name to path always skips the name-space as that is part of the generic path
      # i.e. <module>/mymodule/functions/foo.pp is the function mymodule::foo
      "#{File.join(generic_path, typed_name.name_parts[ 1..-1 ])}.pp"
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

  class FunctionPath3x < RubySmartPath
    FUNCTION_PATH_3X = File.join('puppet', 'parser', 'functions')

    def relative_path
      FUNCTION_PATH_3X
    end

    def instantiator()
      Puppet::Pops::Loader::RubyLegacyFunctionInstantiator
    end
  end

  class FunctionPathPP < PuppetSmartPath
    # Navigate to directory where 'lib' is, then down again
    FUNCTION_PATH_PP = File.join('functions')

    def relative_path
      FUNCTION_PATH_PP
    end

    def instantiator()
      Puppet::Pops::Loader::PuppetFunctionInstantiator
    end
  end

  class TypePathPP < PuppetSmartPath
    # Navigate to directory where 'lib' is, then down again
    TYPE_PATH_PP = File.join('types')

    def relative_path
      TYPE_PATH_PP
    end

    def instantiator()
      Puppet::Pops::Loader::TypeDefinitionInstantiator
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
