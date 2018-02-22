module Puppet::Pops
module Types
  # The {ImplementationRegistry} maps names types in the Puppet Type System to names of corresponding implementation
  # modules/classes. Each mapping is unique and bidirectional so that for any given type name there is only one
  # implementation and vice versa.
  #
  # @api private
  class ImplementationRegistry
    TYPE_REGEXP_SUBST = TypeFactory.tuple([PRegexpType::DEFAULT, PStringType::NON_EMPTY])

    # Create a new instance. This method is normally only called once
    #
    # @param parent [ImplementationRegistry, nil] the parent of this registry
    def initialize(parent = nil)
      @parent = parent
      @type_names_per_implementation = {}
      @implementations_per_type_name = {}
      @type_name_substitutions = []
      @impl_name_substitutions = []
    end

    # Register a bidirectional type mapping.
    #
    # @overload register_type_mapping(runtime_type, puppet_type)
    #   @param runtime_type [PRuntimeType] type that represents the runtime module or class to map to a puppet type
    #   @param puppet_type [PAnyType] type that will be mapped to the runtime module or class
    # @overload register_type_mapping(runtime_type, pattern_replacement)
    #   @param runtime_type [PRuntimeType] type containing the pattern and replacement to map the runtime type to a puppet type
    #   @param puppet_type [Array(Regexp,String)] the pattern and replacement to map a puppet type to a runtime type
    def register_type_mapping(runtime_type, puppet_type_or_pattern, _ = nil)
      TypeAsserter.assert_assignable('First argument of type mapping', PRuntimeType::RUBY, runtime_type)
      expr = runtime_type.name_or_pattern
      if expr.is_a?(Array)
        TypeAsserter.assert_instance_of('Second argument of type mapping', TYPE_REGEXP_SUBST, puppet_type_or_pattern)
        register_implementation_regexp(puppet_type_or_pattern, expr)
      else
        TypeAsserter.assert_instance_of('Second argument of type mapping', PTypeType::DEFAULT, puppet_type_or_pattern)
        register_implementation(puppet_type_or_pattern, expr)
      end
    end

    # Register a bidirectional namespace mapping
    #
    # @param type_namespace [String] the namespace for the puppet types
    # @param impl_namespace [String] the namespace for the implementations
    def register_implementation_namespace(type_namespace, impl_namespace, _ = nil)
      ns = TypeFormatter::NAME_SEGMENT_SEPARATOR
      register_implementation_regexp(
        [/\A#{type_namespace}#{ns}(\w+)\z/, "#{impl_namespace}#{ns}\\1"],
        [/\A#{impl_namespace}#{ns}(\w+)\z/, "#{type_namespace}#{ns}\\1"])
    end

    # Register a bidirectional regexp mapping
    #
    # @param type_name_subst [Array(Regexp,String)] regexp and replacement mapping type names to runtime names
    # @param impl_name_subst [Array(Regexp,String)] regexp and replacement mapping runtime names to type names
    def register_implementation_regexp(type_name_subst, impl_name_subst, _ = nil)
      @type_name_substitutions << type_name_subst
      @impl_name_substitutions << impl_name_subst
      nil
    end

    # Register a bidirectional mapping between a type and an implementation
    #
    # @param type [PAnyType,String] the type or type name
    # @param impl_module[Module,String] the module or module name
    def register_implementation(type, impl_module, _ = nil)
      type = type.name if type.is_a?(PAnyType)
      impl_module = impl_module.name if impl_module.is_a?(Module)
      @type_names_per_implementation[impl_module] = type
      @implementations_per_type_name[type] = impl_module
      nil
    end

    # Find the name for the module that corresponds to the given type or type name
    #
    # @param type [PAnyType,String] the name of the type
    # @return [String,nil] the name of the implementation module, or `nil` if no mapping was found
    def module_name_for_type(type)
      type = type.name if type.is_a?(PAnyType)
      name = @parent.module_name_for_type(type) unless @parent.nil?
      name.nil? ? find_mapping(type, @implementations_per_type_name, @type_name_substitutions) : name
    end

    # Find the module that corresponds to the given type or type name
    #
    # @param type [PAnyType,String] the name of the type
    # @return [Module,nil] the name of the implementation module, or `nil` if no mapping was found
    def module_for_type(type)
      name = module_name_for_type(type)
      # TODO Shouldn't ClassLoader be module specific?
      name.nil? ? nil : ClassLoader.provide(name)
    end

    # Find the type name and loader that corresponds to the given runtime module or module name
    #
    # @param impl_module [Module,String] the implementation class or class name
    # @return [String,nil] the name of the type, or `nil` if no mapping was found
    def type_name_for_module(impl_module)
      impl_module = impl_module.name if impl_module.is_a?(Module)
      name = @parent.type_name_for_module(impl_module) unless @parent.nil?
      name.nil? ? find_mapping(impl_module, @type_names_per_implementation, @impl_name_substitutions) : name
    end

    # Find the name for, and then load, the type  that corresponds to the given runtime module or module name
    # The method will return `nil` if no mapping is found, a TypeReference if a mapping was found but the
    # loader didn't find the type, or the loaded type.
    #
    # @param impl_module [Module,String] the implementation class or class name
    # @return [PAnyType,nil] the type, or `nil` if no mapping was found
    def type_for_module(impl_module)
      name = type_name_for_module(impl_module)
      if name.nil?
        nil
      else
        TypeParser.singleton.parse(name)
      end
    end

    private

    def find_mapping(name, names, substitutions)
      found = names[name]
      if found.nil?
        substitutions.each do |subst|
          substituted = name.sub(*subst)
          return substituted unless substituted == name
        end
      end
      found
    end
  end
end
end
