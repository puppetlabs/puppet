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
      @program_model.definitions.collect do |d|
        case d
        when Puppet::Pops::Model::HostClassDefinition
          instantiate_HostClassDefinition(d, modname)
        when Puppet::Pops::Model::ResourceTypeDefinition
          instantiate_ResourceTypeDefinition(d, modname)
        when Puppet::Pops::Model::NodeDefinition
          instantiate_NodeDefinition(d, modname)
        else
          raise Puppet::ParseError, "Internal Error: Unknown type of definition - got '#{d.class}'"
        end
      end.flatten().compact() # flatten since node definition may have returned an array
                              # Compact since functions are not understood by compiler
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

    private

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
        Puppet.debug("Instantiating Resource with type checked parameters - scope is missing, skipping type checking.")
        nil
      end
      scope
    end

    # Produces a hash with data for Definition and HostClass
    def args_from_definition(o, modname)
      args = {
       :arguments => o.parameters.collect {|p| instantiate_Parameter(p) },
       :argument_types => create_type_map(o),
       :module_name => modname
      }
      unless is_nop?(o.body)
        args[:code] = Expression.new(:value => o.body)
      end
      @ast_transformer.merge_location(args, o)
    end

    def instantiate_HostClassDefinition(o, modname)
      args = args_from_definition(o, modname)
      args[:parent] = absolute_reference(o.parent_class)
      Puppet::Resource::Type.new(:hostclass, o.name, @context.merge(args))
    end

    def instantiate_ResourceTypeDefinition(o, modname)
      Puppet::Resource::Type.new(:definition, o.name, @context.merge(args_from_definition(o, modname)))
    end

    def instantiate_NodeDefinition(o, modname)
      args = { :module_name => modname }

      unless is_nop?(o.body)
        args[:code] = Expression.new(:value => o.body)
      end

      unless is_nop?(o.parent)
        args[:parent] = @ast_transformer.hostname(o.parent)
      end

      host_matches = @ast_transformer.hostname(o.host_matches)
      @ast_transformer.merge_location(args, o)
      host_matches.collect do |name|
        Puppet::Resource::Type.new(:node, name, @context.merge(args))
      end
    end

    # Propagates a found Function to the appropriate loader.
    # This is for 4x future-evaluator/loader
    #
    def instantiate_FunctionDefinition(function_definition, modname)
      loaders = (Puppet.lookup(:loaders) { nil })
      unless loaders
        raise Puppet::ParseError, "Internal Error: Puppet Context ':loaders' missing - cannot define any functions"
      end
      loader =
      if modname.nil? || modname == ""
        # TODO : Later when functions can be private, a decision is needed regarding what that means.
        #        A private environment loader could be used for logic outside of modules, then only that logic
        #        would see the function.
        #
        # Use the private loader, this function may see the environment's dependencies (currently, all modules)
        loaders.private_environment_loader()
      else
        # TODO : Later check if function is private, and then add it to
        #        private_loader_for_module
        #
        loaders.public_loader_for_module(modname)
      end
      unless loader
        raise Puppet::ParseError, "Internal Error: did not find public loader for module: '#{modname}'"
      end

      # Instantiate Function, and store it in the environment loader
      typed_name, f = Puppet::Pops::Loader::PuppetFunctionInstantiator.create_from_model(function_definition, loader)
      loader.set_entry(typed_name, f, Puppet::Pops::Adapters::SourcePosAdapter.adapt(function_definition).to_uri)

      nil # do not want the function to inadvertently leak into 3x
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
