# The TypeDefinitionInstantiator instantiates a type alias or a type definition
#
module Puppet::Pops
module Loader
class TypeDefinitionInstantiator
  def self.create(loader, typed_name, source_ref, pp_code_string)
    # parse and validate
    parser = Parser::EvaluatingParser.new()
    model = parser.parse_string(pp_code_string, source_ref)
    # Only one type is allowed (and no other definitions)

    name = typed_name.name
    case model.definitions.size
    when 0
      raise ArgumentError, _("The code loaded from %{source_ref} does not define the type '%{name}' - it is empty.") % { source_ref: source_ref, name: name }
    when 1
      # ok
    else
      raise ArgumentError,
        _("The code loaded from %{source_ref} must contain only the type '%{name}' - it has additional definitions.") % { source_ref: source_ref, name: name }
    end
    type_definition = model.definitions[0]

    unless type_definition.is_a?(Model::TypeAlias) || type_definition.is_a?(Model::TypeDefinition)
      raise ArgumentError,
        _("The code loaded from %{source_ref} does not define the type '%{name}' - no type alias or type definition found.") % { source_ref: source_ref, name: name }
    end

    actual_name = type_definition.name
    unless name == actual_name.downcase
      raise ArgumentError,
        _("The code loaded from %{source_ref} produced type with the wrong name, expected '%{name}', actual '%{actual_name}'") % { source_ref: source_ref, name: name, actual_name: actual_name }
    end

    unless model.body == type_definition
      raise ArgumentError,
        _("The code loaded from %{source_ref} contains additional logic - can only contain the type '%{name}'") % { source_ref: source_ref, name: name }
    end

    # Adapt the type definition with loader - this is used from logic contained in its body to find the
    # loader to use when resolving contained aliases API. Such logic have a hard time finding the closure (where
    # the loader is known - hence this mechanism
    private_loader = loader.private_loader
    Adapters::LoaderAdapter.adapt(type_definition).loader_name = private_loader.loader_name
    create_runtime_type(type_definition)
  end

  def self.create_from_model(type_definition, loader)
    typed_name = TypedName.new(:type, type_definition.name)
    type = create_runtime_type(type_definition)
    loader.set_entry(
      typed_name,
      type,
      type_definition.locator.to_uri(type_definition))
    type
  end

  # @api private
  def self.create_runtime_type(type_definition)
    # Using the RUNTIME_NAME_AUTHORITY as the name_authority is motivated by the fact that the type
    # alias name (managed by the runtime) becomes the name of the created type
    #
    create_type(type_definition.name, type_definition.type_expr, Pcore::RUNTIME_NAME_AUTHORITY)
  end

  # @api private
  def self.create_type(name, type_expr, name_authority)
    create_named_type(name, named_definition(type_expr), type_expr, name_authority)
  end

  # @api private
  def self.create_named_type(name, type_name, type_expr, name_authority)
    case type_name
    when 'Object'
      # No need for an alias. The Object type itself will receive the name instead
      unless type_expr.is_a?(Model::LiteralHash)
        type_expr = type_expr.keys.empty? ? nil : type_expr.keys[0] unless type_expr.is_a?(Hash)
      end
      Types::PObjectType.new(name, type_expr)
    when 'TypeSet'
      # No need for an alias. The Object type itself will receive the name instead
      type_expr = type_expr.keys.empty? ? nil : type_expr.keys[0] unless type_expr.is_a?(Hash)
      Types::PTypeSetType.new(name, type_expr, name_authority)
    else
      Types::PTypeAliasType.new(name, type_expr)
    end
  end

  # @api private
  def self.named_definition(te)
    return 'Object' if te.is_a?(Model::LiteralHash)
    te.is_a?(Model::AccessExpression) && (left = te.left_expr).is_a?(Model::QualifiedReference) ? left.cased_value : nil
  end

  def several_paths?
    false
  end
end
end
end
