
# LoaderPaths
# ===
# The central loader knowledge about paths, what they represent and how to instantiate from them.
# Contains helpers (*smart paths*) to deal with lazy resolution of paths.
#
# TODO: Currently only supports loading of functions (2 kinds)
#
module Puppet::Pops
module Loader
module LoaderPaths

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
    when :plan
      result << PlanPathPP.new(loader)
    when :task
      result << TaskPath.new(loader) if Puppet[:tasks] && loader.loadables.include?(:task)
    when :type
      result << DataTypePath.new(loader) if loader.loadables.include?(:datatype)
      result << TypePathPP.new(loader) if loader.loadables.include?(:type_pp)
    when :resource_type_pp
      result << ResourceTypeImplPP.new(loader) if loader.loadables.include?(:resource_type_pp)
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

    def generic_path
      return @generic_path unless @generic_path.nil?

      the_root_path = root_path # @loader.path
      @generic_path = (the_root_path.nil? ? relative_path : File.join(the_root_path, relative_path))
    end

    def match_many?
      false
    end

    def root_path
      @loader.path
    end

    def lib_root?
      @loader.lib_root?
    end

    # Effective path is the generic path + the name part(s) + extension.
    #
    def effective_path(typed_name, start_index_in_name)
      "#{File.join(generic_path, typed_name.name_parts)}#{extension}"
    end

    def typed_name(type, name_authority, relative_path, module_name)
      # Module name is assumed to be included in the path and therefore not added here
      n = ''
      unless extension.empty?
        # Remove extension
        relative_path = relative_path[0..-(extension.length+1)]
      end
      relative_path.split('/').each do |segment|
        n << '::' if n.size > 0
        n << segment
      end
      TypedName.new(type, n, name_authority)
    end

    def valid_path?(path)
      path.end_with?(extension) && path.start_with?(generic_path)
    end

    def valid_name?(typed_name)
      true
    end

    def relative_path
      raise NotImplementedError.new
    end

    def instantiator
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

    # Duplication of extension information, but avoids one call
    def effective_path(typed_name, start_index_in_name)
      # Puppet name to path always skips the name-space as that is part of the generic path
      # i.e. <module>/mymodule/functions/foo.pp is the function mymodule::foo
      parts = typed_name.name_parts
      if start_index_in_name > 0
        return nil if start_index_in_name >= parts.size
        parts = parts[start_index_in_name..-1]
      end
      "#{File.join(generic_path, parts)}#{extension}"
    end

    def typed_name(type, name_authority, relative_path, module_name)
      n = ''
      n << module_name unless module_name.nil?
      unless extension.empty?
        # Remove extension
        relative_path = relative_path[0..-(extension.length+1)]
      end
      relative_path.split('/').each do |segment|
        n << '::' if n.size > 0
        n << segment
      end
      TypedName.new(type, n, name_authority)
    end
  end

  class FunctionPath4x < RubySmartPath
    SYSTEM_FUNCTION_PATH_4X = File.join('puppet', 'functions').freeze
    FUNCTION_PATH_4X = File.join('lib', SYSTEM_FUNCTION_PATH_4X).freeze

    def relative_path
      lib_root? ? SYSTEM_FUNCTION_PATH_4X : FUNCTION_PATH_4X
    end

    def instantiator
      RubyFunctionInstantiator
    end
  end

  class FunctionPath3x < RubySmartPath
    SYSTEM_FUNCTION_PATH_3X = File.join('puppet', 'parser', 'functions').freeze
    FUNCTION_PATH_3X = File.join('lib', SYSTEM_FUNCTION_PATH_3X).freeze

    def relative_path
      lib_root? ? SYSTEM_FUNCTION_PATH_3X : FUNCTION_PATH_3X
    end

    def instantiator
      RubyLegacyFunctionInstantiator
    end
  end

  class FunctionPathPP < PuppetSmartPath
    FUNCTION_PATH_PP = 'functions'.freeze

    def relative_path
      FUNCTION_PATH_PP
    end

    def instantiator
      PuppetFunctionInstantiator
    end
  end

  class DataTypePath < RubySmartPath
    SYSTEM_TYPE_PATH = File.join('puppet', 'datatypes').freeze
    TYPE_PATH = File.join('lib', SYSTEM_TYPE_PATH).freeze

    def relative_path
      lib_root? ? SYSTEM_TYPE_PATH : TYPE_PATH
    end

    def instantiator
      RubyDataTypeInstantiator
    end
  end

  class TypePathPP < PuppetSmartPath
    TYPE_PATH_PP = 'types'.freeze

    def relative_path
      TYPE_PATH_PP
    end

    def instantiator
      TypeDefinitionInstantiator
    end
  end

  # TaskPath is like PuppetSmartPath but it does not use an extension and may
  # match more than one path with one name
  class TaskPath < PuppetSmartPath
    TASKS_PATH = 'tasks'.freeze
    FORBIDDEN_EXTENSIONS = %w{.conf .md}.freeze

    def extension
      EMPTY_STRING
    end

    def match_many?
      true
    end

    def relative_path
      TASKS_PATH
    end

    def typed_name(type, name_authority, relative_path, module_name)
      n = ''
      n << module_name unless module_name.nil?

      # Remove the file extension, defined as everything after the *last* dot.
      relative_path = relative_path.sub(%r{\.[^/.]*\z}, '')

      if relative_path == 'init' && !(module_name.nil? || module_name.empty?)
        TypedName.new(type, module_name, name_authority)
      else
        relative_path.split('/').each do |segment|
          n << '::' if n.size > 0
          n << segment
        end
        TypedName.new(type, n, name_authority)
      end
    end

    def instantiator
      require_relative 'task_instantiator'
      TaskInstantiator
    end

    def valid_name?(typed_name)
      # TODO: Remove when PE has proper namespace handling
      typed_name.name_parts.size <= 2
    end

    def valid_path?(path)
      path.start_with?(generic_path) && is_task_name?(File.basename(path, '.*')) && !FORBIDDEN_EXTENSIONS.any? { |ext| path.end_with?(ext) }
    end

    def is_task_name?(name)
      !!(name =~ /^[a-z][a-z0-9_]*$/)
    end
  end

  class ResourceTypeImplPP < PuppetSmartPath
    RESOURCE_TYPES_PATH_PP = '.resource_types'.freeze

    def relative_path
      RESOURCE_TYPES_PATH_PP
    end

    def root_path
      @loader.path
    end

    def instantiator
      PuppetResourceTypeImplInstantiator
    end

    # The effect paths for resource type impl is the full name
    # since resource types are not name spaced.
    # This overrides the default PuppetSmartPath.
    #
    def effective_path(typed_name, start_index_in_name)
      # Resource type to name does not skip the name-space
      # i.e. <module>/mymodule/resource_types/foo.pp is the resource type foo
      "#{File.join(generic_path, typed_name.name_parts)}.pp"
    end
  end

  class PlanPathPP < PuppetSmartPath
    PLAN_PATH_PP = File.join('plans')

    def relative_path
      PLAN_PATH_PP
    end

    def instantiator()
      Puppet::Pops::Loader::PuppetPlanInstantiator
    end

    def typed_name(type, name_authority, relative_path, module_name)
      if relative_path == 'init.pp' && !(module_name.nil? || module_name.empty?)
        TypedName.new(type, module_name, name_authority)
      else
        n = ''
        n << module_name unless module_name.nil?
        unless extension.empty?
          # Remove extension
          relative_path = relative_path[0..-(extension.length+1)]
        end
        relative_path.split('/').each do |segment|
          n << '::' if n.size > 0
          n << segment
        end
        TypedName.new(type, n, name_authority)
      end
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
        paths_for_type = LoaderPaths.relative_paths_for_type(type, loader)
        # Check which directories exist in the loader's content/index
        effective_paths = smart_paths[type] = paths_for_type.select { |sp| loader.meaningful_to_search?(sp) }
      end
      effective_paths
    end
  end
end
end
end

