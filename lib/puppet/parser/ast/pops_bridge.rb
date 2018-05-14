require 'puppet/parser/ast/top_level_construct'
require 'puppet/pops'

# The AST::Bridge contains classes that bridges between the new Pops based model
# and the 3.x AST. This is required to be able to reuse the Puppet::Resource::Type which is
# fundamental for the rest of the logic.
#
class Puppet::Parser::AST::PopsBridge

  # Bridges to one Pops Model Expression
  # The @value is the expression
  # This is used to represent the body of a class, definition, or node, and for each parameter's default value
  # expression.
  #
  class Expression < Puppet::Parser::AST::Leaf

    def initialize args
      super
      @@evaluator ||= Puppet::Pops::Parser::EvaluatingParser.new()
    end

    def to_s
      Puppet::Pops::Model::ModelTreeDumper.new.dump(@value)
    end

    def source_text
      source_adapter = Puppet::Pops::Utils.find_closest_positioned(@value)
      source_adapter ? source_adapter.extract_text() : nil
    end

    def evaluate(scope)
      object = @@evaluator.evaluate(scope, @value)
      @@evaluator.convert_to_3x(object, scope)
    end

    # Adapts to 3x where top level constructs needs to have each to iterate over children. Short circuit this
    # by yielding self. By adding this there is no need to wrap a pops expression inside an AST::BlockExpression
    #
    def each
      yield self
    end

    def sequence_with(other)
      if value.nil?
        # This happens when testing and not having a complete setup
        other
      else
        # When does this happen ? Ever ?
        raise "sequence_with called on Puppet::Parser::AST::PopsBridge::Expression - please report use case"
        # What should be done if the above happens (We don't want this to happen).
        # Puppet::Parser::AST::BlockExpression.new(:children => [self] + other.children)
      end
    end

    # The 3x requires code plugged in to an AST to have this in certain positions in the tree. The purpose
    # is to either print the content, or to look for things that needs to be defined. This implementation
    # cheats by always returning an empty array. (This allows simple files to not require a "Program" at the top.
    #
    def children
      []
    end
  end

  class ExpressionSupportingReturn < Expression
    def initialize args
      super
    end

    def evaluate(scope)
      return catch(:return) do
        return catch(:next) do
          return super(scope)
        end
      end
    end
  end
  # Bridges the top level "Program" produced by the pops parser.
  # Its main purpose is to give one point where all definitions are instantiated (actually defined since the
  # Puppet 3x terminology is somewhat misleading - the definitions are instantiated, but instances of the created types
  # are not created, that happens when classes are included / required, nodes are matched and when resources are instantiated
  # by a resource expression (which is also used to instantiate a host class).
  #
  class Program < Puppet::Parser::AST::TopLevelConstruct
    attr_reader :program_model, :context

    def initialize(program_model, context = {})
      @program_model = program_model
      @context = context
      @ast_transformer ||= Puppet::Pops::Model::AstTransformer.new(@context[:file])
      @@evaluator ||= Puppet::Pops::Parser::EvaluatingParser.new()
    end

    # This is the 3x API, the 3x AST searches through all code to find the instructions that can be instantiated.
    # This Pops-model based instantiation relies on the parser to build this list while parsing (which is more
    # efficient as it avoids one full scan of all logic via recursive enumeration/yield)
    #
    def instantiate(modname)

      @program_model.definitions.map do |d|
        case d
        when Puppet::Pops::Model::HostClassDefinition
          instantiate_HostClassDefinition(d, modname)
        when Puppet::Pops::Model::ResourceTypeDefinition
          instantiate_ResourceTypeDefinition(d, modname)
        when Puppet::Pops::Model::CapabilityMapping
          instantiate_CapabilityMapping(d, modname)
        when Puppet::Pops::Model::NodeDefinition
          instantiate_NodeDefinition(d, modname)
        when Puppet::Pops::Model::SiteDefinition
            instantiate_SiteDefinition(d, modname)
        when Puppet::Pops::Model::Application
          instantiate_ApplicationDefinition(d, modname)
        else
          loaders = Puppet::Pops::Loaders.loaders
          loaders.instantiate_definition(d, loaders.find_loader(modname))

          # The 3x logic calling this will not know what to do with the result, it is compacted away at the end
          nil
        end
      end.flatten().compact() # flatten since node definition may have returned an array
                              # Compact since 4x definitions are not understood by compiler
    end

    def evaluate(scope)
      @@evaluator.evaluate(scope, program_model)
    end

    # Adapts to 3x where top level constructs needs to have each to iterate over children. Short circuit this
    # by yielding self. This means that the HostClass container will call this bridge instance with `instantiate`.
    #
    def each
      yield self
    end

    # Returns true if this Program only contains definitions
    def is_definitions_only?
      is_definition?(program_model)
    end

    private

    def is_definition?(o)
      case o
      when Puppet::Pops::Model::Program
        is_definition?(o.body)
      when Puppet::Pops::Model::BlockExpression
        o.statements.all {|s| is_definition?(s) }
      when Puppet::Pops::Model::Definition
        true
      else
        false
      end
    end

    def instantiate_Parameter(o)
      # 3x needs parameters as an array of `[name]` or `[name, value_expr]`
      if o.value
        [o.name, Expression.new(:value => o.value)]
      else
        [o.name]
      end
    end

    def create_type_map(definition)
      result = {}
      # No need to do anything if there are no parameters
      return result unless definition.parameters.size > 0

      # No need to do anything if there are no typed parameters
      typed_parameters = definition.parameters.select {|p| p.type_expr }
      return result if typed_parameters.empty?

      # If there are typed parameters, they need to be evaluated to produce the corresponding type
      # instances. This evaluation requires a scope. A scope is not available when doing deserialization
      # (there is also no initialized evaluator). When running apply and test however, the environment is
      # reused and we may reenter without a scope (which is fine). A debug message is then output in case
      # there is the need to track down the odd corner case. See {#obtain_scope}.
      #
      if scope = obtain_scope
        typed_parameters.each do |p|
          result[p.name] =  @@evaluator.evaluate(scope, p.type_expr)
        end
      end
      result
    end

    # Obtains the scope or issues a warning if :global_scope is not bound
    def obtain_scope
      scope = Puppet.lookup(:global_scope) do
        # This occurs when testing and when applying a catalog (there is no scope available then), and
        # when running tests that run a partial setup.
        # This is bad if the logic is trying to compile, but a warning can not be issues since it is a normal
        # use case that there is no scope when requesting the type in order to just get the parameters.
        Puppet.debug {_("Instantiating Resource with type checked parameters - scope is missing, skipping type checking.")}
        nil
      end
      scope
    end

    # Produces a hash with data for Definition and HostClass
    def args_from_definition(o, modname, expr_class = Expression)
      args = {
       :arguments => o.parameters.collect {|p| instantiate_Parameter(p) },
       :argument_types => create_type_map(o),
       :module_name => modname
      }
      unless is_nop?(o.body)
        args[:code] = expr_class.new(:value => o.body)
      end
      @ast_transformer.merge_location(args, o)
    end

    def instantiate_HostClassDefinition(o, modname)
      args = args_from_definition(o, modname, ExpressionSupportingReturn)
      args[:parent] = absolute_reference(o.parent_class)
      Puppet::Resource::Type.new(:hostclass, o.name, @context.merge(args))
    end

    def instantiate_ResourceTypeDefinition(o, modname)
      instance = Puppet::Resource::Type.new(:definition, o.name, @context.merge(args_from_definition(o, modname, ExpressionSupportingReturn)))
      Puppet::Pops::Loaders.register_runtime3_type(instance.name, o.locator.to_uri(o))
      instance
    end

    def instantiate_CapabilityMapping(o, modname)
      # Use an intermediate 'capability_mapping' type to pass this info to the compiler where the
      # actual mapping takes place
      Puppet::Resource::Type.new(:capability_mapping, "#{o.component} #{o.kind} #{o.capability}", { :arguments => {
        'component'     => o.component,
        'kind'          => o.kind,
        'blueprint'     => {
          :capability => o.capability,
          :mappings   => o.mappings.reduce({}) do |memo, mapping|
            memo[mapping.attribute_name] =
              Expression.new(:value => mapping.value_expr)
            memo
          end
      }}})
    end

    def instantiate_ApplicationDefinition(o, modname)
      args = args_from_definition(o, modname)
      Puppet::Resource::Type.new(:application, o.name, @context.merge(args))
    end

    def instantiate_NodeDefinition(o, modname)
      args = { :module_name => modname }

      unless is_nop?(o.body)
        args[:code] = Expression.new(:value => o.body)
      end

      unless is_nop?(o.parent)
        args[:parent] = @ast_transformer.hostname(o.parent)
      end
      args = @ast_transformer.merge_location(args, o)

      host_matches = @ast_transformer.hostname(o.host_matches)
      host_matches.collect do |name|
        Puppet::Resource::Type.new(:node, name, @context.merge(args))
      end
    end

    def instantiate_SiteDefinition(o, modname)
      args = { :module_name => modname }

      unless is_nop?(o.body)
        args[:code] = Expression.new(:value => o.body)
      end

      args = @ast_transformer.merge_location(args, o)
      Puppet::Resource::Type.new(:site, 'site', @context.merge(args))
    end

    def code()
      Expression.new(:value => @value)
    end

    def is_nop?(o)
      @ast_transformer.is_nop?(o)
    end

    def absolute_reference(ref)
      if ref.nil? || ref.empty? || ref.start_with?('::')
        ref
      else
        "::#{ref}"
      end
    end
  end
end
