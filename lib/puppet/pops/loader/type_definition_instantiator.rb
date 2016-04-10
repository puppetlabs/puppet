# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
module Puppet::Pops
module Loader
class TypeDefinitionInstantiator
  def self.create(loader, typed_name, source_ref, pp_code_string)
    # parse and validate
    parser = Parser::EvaluatingParser.new()
    model = parser.parse_string(pp_code_string, source_ref).model
    # Only one type is allowed (and no other definitions)

    name = typed_name.name
    case model.definitions.size
    when 0
      raise ArgumentError, "The code loaded from #{source_ref} does not define the type '#{name}' - it is empty."
    when 1
      # ok
    else
      raise ArgumentError,
        "The code loaded from #{source_ref} must contain only the type '#{name}' - it has additional definitions."
    end
    type_definition = model.definitions[0]

    unless type_definition.is_a?(Model::TypeAlias) || type_definition.is_a?(Model::TypeDefinition)
      raise ArgumentError,
        "The code loaded from #{source_ref} does not define the type '#{name}' - no type alias or type definition found."
    end

    actual_name = type_definition.name
    unless name == actual_name.downcase
      raise ArgumentError,
        "The code loaded from #{source_ref} produced type with the wrong name, expected '#{name}', actual '#{actual_name}'"
    end

    unless model.body == type_definition
      raise ArgumentError,
        "The code loaded from #{source_ref} contains additional logic - can only contain the type '#{name}'"
    end

    # Adapt the type definition with loader - this is used from logic contained in its body to find the
    # loader to use when resolving contained aliases API. Such logic have a hard time finding the closure (where
    # the loader is known - hence this mechanism
    private_loader = loader.private_loader
    Adapters::LoaderAdapter.adapt(type_definition).loader = private_loader
    create_type(type_definition, loader)
  end

  def self.create_from_model(type_definition, loader)
    typed_name = Loader::TypedName.new(:type, type_definition.name.downcase)
    type = create_type(type_definition, loader)
    loader.set_entry(
      typed_name,
      type,
      Adapters::SourcePosAdapter.adapt(type_definition).to_uri)
    type
  end

  def self.create_type(type_definition, loader)
    type_expr = type_definition.type_expr
    name = type_definition.name
    if object_definition?(type_expr)
      # No need for an alias. The Object type itself will receive the name instead
      i12n_hash_expr = type_expr.keys.empty? ? nil : type_expr.keys[0]
      Types::PObjectType.new(name, i12n_hash_expr)
    else
      Types::PTypeAliasType.new(name, type_expr)
    end
  end
  private_class_method :create_type

  def self.object_definition?(te)
    te.is_a?(Model::AccessExpression) && (left = te.left_expr).is_a?(Model::QualifiedReference) && left.cased_value == 'Object'
  end
  private_class_method :object_definition?
end
end
end
