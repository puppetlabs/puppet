# @abstract base class for PObjectType and other types that implements lazy evaluation of content
# @api private
module Puppet::Pops
module Types

KEY_NAME = 'name'.freeze
KEY_TYPE = 'type'.freeze
KEY_VALUE = 'value'.freeze

class PMetaType < PAnyType
  include Annotatable

  attr_reader :loader

  def self.register_ptype(loader, ir)
    # Abstract type. It doesn't register anything
  end

  def accept(visitor, guard)
    annotatable_accept(visitor, guard)
    super
  end

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  # Called from the TypeParser once it has found a type using the Loader. The TypeParser will
  # interpret the contained expression and the resolved type is remembered. This method also
  # checks and remembers if the resolve type contains self recursion.
  #
  # @param type_parser [TypeParser] type parser that will interpret the type expression
  # @param loader [Loader::Loader] loader to use when loading type aliases
  # @return [PTypeAliasType] the receiver of the call, i.e. `self`
  # @api private
  def resolve(loader)
    unless @init_hash_expression.nil?
      @loader = loader
      @self_recursion = true # assumed while it being found out below

      init_hash_expression = @init_hash_expression
      @init_hash_expression = nil
      if init_hash_expression.is_a?(Model::LiteralHash)
        init_hash = resolve_literal_hash(loader, init_hash_expression)
      else
        init_hash = resolve_hash(loader, init_hash_expression)
      end
      _pcore_init_from_hash(init_hash)

      # Find out if this type is recursive. A recursive type has performance implications
      # on several methods and this knowledge is used to avoid that for non-recursive
      # types.
      guard = RecursionGuard.new
      accept(NoopTypeAcceptor::INSTANCE, guard)
      @self_recursion = guard.recursive_this?(self)
    end
    self
  end

  def resolve_literal_hash(loader, init_hash_expression)
    TypeParser.singleton.interpret_LiteralHash(init_hash_expression, loader)
  end

  def resolve_hash(loader, init_hash)
    resolve_type_refs(loader, init_hash)
  end

  def resolve_type_refs(loader, o)
    case o
    when Hash
      Hash[o.map { |k, v| [resolve_type_refs(loader, k), resolve_type_refs(loader, v)] }]
    when Array
      o.map { |e| resolve_type_refs(loader, e) }
    when PAnyType
      o.resolve(loader)
    else
      o
    end
  end

  def resolved?
    @init_hash_expression.nil?
  end

  # Returns the expanded string the form of the alias, e.g. <alias name> = <resolved type>
  #
  # @return [String] the expanded form of this alias
  # @api public
  def to_s
    TypeFormatter.singleton.alias_expanded_string(self)
  end
end
end
end
