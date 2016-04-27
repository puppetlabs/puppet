# @abstract base class for PObjectType and other types that implements lazy evaluation of content
# @api private
module Puppet::Pops
module Types
class PMetaType < PAnyType
  KEY_NAME = 'name'.freeze

  # Called from the TypeParser once it has found a type using the Loader. The TypeParser will
  # interpret the contained expression and the resolved type is remembered. This method also
  # checks and remembers if the resolve type contains self recursion.
  #
  # @param type_parser [TypeParser] type parser that will interpret the type expression
  # @param loader [Loader::Loader] loader to use when loading type aliases
  # @return [PTypeAliasType] the receiver of the call, i.e. `self`
  # @api private
  def resolve(type_parser, loader)
    unless @i12n_hash_expression.nil?
      @self_recursion = true # assumed while it being found out below

      i12n_hash_expression = @i12n_hash_expression
      @i12n_hash_expression = nil
      if i12n_hash_expression.is_a?(Model::LiteralHash)
        i12n_hash = resolve_literal_hash(type_parser, loader, i12n_hash_expression)
      else
        i12n_hash = resolve_hash(type_parser, loader, i12n_hash_expression)
      end
      initialize_from_hash(i12n_hash)

      # Find out if this type is recursive. A recursive type has performance implications
      # on several methods and this knowledge is used to avoid that for non-recursive
      # types.
      guard = RecursionGuard.new
      accept(NoopTypeAcceptor::INSTANCE, guard)
      @self_recursion = guard.recursive_this?(self)
    end
    self
  end

  def resolve_literal_hash(type_parser, loader, i12n_hash_expression)
    type_parser.interpret_LiteralHash(i12n_hash_expression, loader)
  end

  def resolve_hash(type_parser, loader, i12n_hash)
    resolve_type_refs(type_parser, loader, i12n_hash)
  end

  def resolve_type_refs(type_parser, loader, o)
    case o
    when Hash
      Hash[o.map { |k, v| [resolve_type_refs(type_parser, loader, k), resolve_type_refs(type_parser, loader, v)] }]
    when Array
      o.map { |e| resolve_type_refs(type_parser, loader, e) }
    when PTypeReferenceType
      o.resolve(type_parser, loader)
    else
      o
    end
  end
end
end
end