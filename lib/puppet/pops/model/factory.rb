# Factory is a helper class that makes construction of a Pops Model
# much more convenient. It can be viewed as a small internal DSL for model
# constructions.
# For usage see tests using the factory.
#
# @todo All those uppercase methods ... they look bad in one way, but stand out nicely in the grammar...
#   decide if they should change into lower case names (some of the are lower case)...
#
module Puppet::Pops
module Model
class Factory
  attr_accessor :current

  alias_method :model, :current

  # Shared build_visitor, since there are many instances of Factory being used
  @@build_visitor = Visitor.new(self, "build")
  @@interpolation_visitor = Visitor.new(self, "interpolate")

  # Initialize a factory with a single object, or a class with arguments applied to build of
  # created instance
  #
  def initialize(o, *args)
    @current = if o.instance_of?(Class)
      @@build_visitor.visit_this(self, o.new, args)
    elsif o.is_a?(PopsObject)
      o
    elsif o.instance_of?(Factory)
      o.current
    else
      @@build_visitor.visit_this(self, o, args)
    end
  end

  # Polymorphic build
  def build(o, *args)
    @@build_visitor.visit_this(self, o, args)
  end

  # Polymorphic interpolate
  def interpolate()
    @@interpolation_visitor.visit_this_0(self, current)
  end

  # Building of Model classes

  def build_Application(o, n, ps, body)
    o.name = n
    ps.each { |p| o.addParameters(build(p)) }
    b = f_build_body(body)
    o.body = b.current if b
    o
  end

  def build_ArithmeticExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  def build_AssignmentExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  def build_AttributeOperation(o, name, op, value)
    o.operator = op
    o.attribute_name = name.to_s # BOOLEAN is allowed in the grammar
    o.value_expr = build(value)
    o
  end

  def build_AttributesOperation(o, value)
    o.expr = build(value)
    o
  end

  def build_AccessExpression(o, left, *keys)
    o.left_expr = to_ops(left)
    o.keys = keys.map {|expr| to_ops(expr) }
    o
  end

  def build_BinaryExpression(o, left, right)
    o.left_expr = to_ops(left)
    o.right_expr = to_ops(right)
    o
  end

  def build_BlockExpression(o, *args)
    o.statements = args.map {|expr| to_ops(expr) }
    o
  end

  def build_CollectExpression(o, type_expr, query_expr, attribute_operations)
    o.type_expr = to_ops(type_expr)
    o.query = build(query_expr)
    o.operations = attribute_operations.map {|op| build(op) }
    o
  end

  def build_ComparisonExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  def build_ConcatenatedString(o, *args)
    o.segments = args.map {|expr| build(expr) }
    o
  end

  def build_CreateTypeExpression(o, name, super_name = nil)
    o.name = name
    o.super_name = super_name
    o
  end

  def build_CreateEnumExpression(o, *args)
    o.name = args.slice(0) if args.size == 2
    o.values = build(args.last)
    o
  end

  def build_CreateAttributeExpression(o, name, datatype_expr)
    o.name = name
    o.type = to_ops(datatype_expr)
    o
  end

  def build_HeredocExpression(o, name, expr)
    o.syntax = name
    o.text_expr = build(expr)
    o
  end

  # @param name [String] a valid classname
  # @param parameters [Array<Parameter>] may be empty
  # @param parent_class_name [String, nil] a valid classname referencing a parent class, optional.
  # @param body [Array<Expression>, Expression, nil] expression that constitute the body
  # @return [HostClassDefinition] configured from the parameters
  #
  def build_HostClassDefinition(o, name, parameters, parent_class_name, body)
    build_NamedDefinition(o, name, parameters, body)
    o.parent_class = parent_class_name if parent_class_name
    o
  end

  def build_ResourceOverrideExpression(o, resources, attribute_operations)
    o.resources = build(resources)
    o.operations = attribute_operations.map {|ao| build(ao) }
    o
  end

  def build_ReservedWord(o, name, future)
    o.word = name
    o.future = future
    o
  end

  def build_KeyedEntry(o, k, v)
    o.key = to_collection_entry(to_ops(k))
    o.value = to_collection_entry(to_ops(v))
    o
  end

  def build_LiteralHash(o, *keyed_entries)
    o.entries = keyed_entries.map {|entry| build(entry) }
    o
  end

  def to_collection_entry(o)
    if o.is_a?(Model::ReservedWord)
      case o.word
      when 'application', 'site', 'produces', 'consumes'
        build(o.word)
      else
        o
      end
    else
      o
    end
  end

  def build_LiteralList(o, *values)
    o.values = values.map {|v| to_collection_entry(build(v)) }
    o
  end

  def build_LiteralFloat(o, val)
    o.value = val
    o
  end

  def build_LiteralInteger(o, val, radix)
    o.value = val
    o.radix = radix
    o
  end

  def build_IfExpression(o, t, ift, els)
    o.test = build(t)
    o.then_expr = build(ift)
    o.else_expr= build(els)
    o
  end

  def build_MatchExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  # Builds body :) from different kinds of input
  # @overload f_build_body(nothing)
  #   @param nothing [nil] unchanged, produces nil
  # @overload f_build_body(array)
  #   @param array [Array<Expression>] turns into a BlockExpression
  # @overload f_build_body(expr)
  #   @param expr [Expression] produces the given expression
  # @overload f_build_body(obj)
  #   @param obj [Object] produces the result of calling #build with body as argument
  def f_build_body(body)
    case body
    when NilClass
      nil
    when Array
      Factory.new(BlockExpression, *body)
    else
      build(body)
    end
  end

  def build_LambdaExpression(o, parameters, body)
    o.parameters = parameters.map {|p| build(p) }
    b = f_build_body(body)
    o.body = to_ops(b) if b
    o
  end

  def build_NamedDefinition(o, name, parameters, body)
    o.parameters = parameters.map {|p| build(p) }
    b = f_build_body(body)
    o.body = b.current if b
    o.name = name
    o
  end

  def build_CapabilityMapping(o, kind, component, capability, mappings)
    o.kind = kind
    component = component.current if component.instance_of?(Factory)
    o.component = component
    o.capability = capability
    o.mappings = mappings.map { |m| build(m) }
    o
  end

  # @param o [NodeDefinition]
  # @param hosts [Array<Expression>] host matches
  # @param parent [Expression] parent node matcher
  # @param body [Object] see {#f_build_body}
  def build_NodeDefinition(o, hosts, parent, body)
    o.host_matches = hosts.map {|h| build(h) }
    o.parent = build(parent) if parent # no nop here
    b = f_build_body(body)
    o.body = b.current if b
    o
  end

  # @param o [SiteDefinition]
  # @param body [Object] see {#f_build_body}
  def build_SiteDefinition(o, body)
    b = f_build_body(body)
    o.body = b.current if b
    o
  end

  def build_Parameter(o, name, expr)
    o.name = name
    o.value = build(expr) if expr # don't build a nil/nop
    o
  end

  def build_QualifiedReference(o, name)
    o.cased_value = name.to_s
    o
  end

  def build_RelationshipExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  def build_ResourceExpression(o, type_name, bodies)
    o.type_name = build(type_name)
    o.bodies = bodies.map {|b| build(b) }
    o
  end

  def build_RenderStringExpression(o, string)
    o.value = string;
    o
  end

  def build_ResourceBody(o, title_expression, attribute_operations)
    o.title = build(title_expression)
    o.operations = attribute_operations.map {|ao| build(ao) }
    o
  end

  def build_ResourceDefaultsExpression(o, type_ref, attribute_operations)
    o.type_ref = build(type_ref)
    o.operations = attribute_operations.map {|ao| build(ao) }
    o
  end

  def build_SelectorExpression(o, left, *selectors)
    o.left_expr = to_ops(left)
    o.selectors = selectors.map {|s| build(s) }
    o
  end

  # Builds a SubLocatedExpression - this wraps the expression in a sublocation configured
  # from the given token
  # A SubLocated holds its own locator that is used for subexpressions holding positions relative
  # to what it describes.
  #
  def build_SubLocatedExpression(o, token, expression)
    o.expr = build(expression)
    o.offset = token.offset
    o.length =  token.length
    locator = token.locator
    o.locator = locator
    o.leading_line_count = locator.leading_line_count
    o.leading_line_offset = locator.leading_line_offset
    # Index is held in sublocator's parent locator - needed to be able to reconstruct
    o.line_offsets = locator.locator.line_index
    o
  end

  def build_SelectorEntry(o, matching, value)
    o.matching_expr = build(matching)
    o.value_expr = build(value)
    o
  end

  def build_QueryExpression(o, expr)
    ops = to_ops(expr)
    o.expr = ops unless Factory.nop? ops
    o
  end

  def build_TypeAlias(o, name, type_expr)
    o.type_expr = to_ops(type_expr)
    o.name = to_ops(name).cased_value
    o
  end

  def build_TypeMapping(o, lhs, rhs)
    o.type_expr = to_ops(lhs)
    o.mapping_expr = to_ops(rhs)
    o
  end

  def build_TypeDefinition(o, name, parent, body)
    b = f_build_body(body)
    o.body = b.current if b
    o.parent = parent
    o.name = name
    o
  end

  def build_UnaryExpression(o, expr)
    ops = to_ops(expr)
    o.expr = ops unless Factory.nop? ops
    o
  end

  def build_Program(o, body, definitions, locator)
    o.body = to_ops(body)
    # non containment
    o.definitions = definitions
    o.source_ref = locator.file
    o.source_text = locator.string
    o.line_offsets = locator.line_index
    o.locator = locator
    o
  end

  def build_QualifiedName(o, name)
    o.value = name.to_s
    o
  end

  def build_TokenValue(o)
    raise "Factory can not deal with a Lexer Token. Got token: #{o}. Probably caused by wrong index in grammar val[n]."
  end

  # Factory helpers
  def f_build_unary(klazz, expr)
    Factory.new(build(klazz, expr))
  end

  def f_build_binary_op(klazz, op, left, right)
    Factory.new(build(klazz, op, left, right))
  end

  def f_build_binary(klazz, left, right)
    Factory.new(build(klazz, left, right))
  end

  def f_build_vararg(klazz, left, *arg)
    Factory.new(build(klazz, left, *arg))
  end

  def f_arithmetic(op, r)
    f_build_binary_op(ArithmeticExpression, op, current, r)
  end

  def f_comparison(op, r)
    f_build_binary_op(ComparisonExpression, op, current, r)
  end

  def f_match(op, r)
    f_build_binary_op(MatchExpression, op, current, r)
  end

  # Operator helpers
  def in(r)     f_build_binary(InExpression, current, r);          end

  def or(r)     f_build_binary(OrExpression, current, r);          end

  def and(r)    f_build_binary(AndExpression, current, r);         end

  def not();    f_build_unary(NotExpression, self);                end

  def minus();  f_build_unary(UnaryMinusExpression, self);         end

  def unfold(); f_build_unary(UnfoldExpression, self);             end

  def text();   f_build_unary(TextExpression, self);               end

  def var();    f_build_unary(VariableExpression, self);           end

  def [](*r);   f_build_vararg(AccessExpression, current, *r);     end

  def dot r;    f_build_binary(NamedAccessExpression, current, r); end

  def + r;      f_arithmetic(:+, r);                                      end

  def - r;      f_arithmetic(:-, r);                                      end

  def / r;      f_arithmetic(:/, r);                                      end

  def * r;      f_arithmetic(:*, r);                                      end

  def % r;      f_arithmetic(:%, r);                                      end

  def << r;     f_arithmetic(:<<, r);                                     end

  def >> r;     f_arithmetic(:>>, r);                                     end

  def < r;      f_comparison(:<, r);                                      end

  def <= r;     f_comparison(:<=, r);                                     end

  def > r;      f_comparison(:>, r);                                      end

  def >= r;     f_comparison(:>=, r);                                     end

  def == r;     f_comparison(:==, r);                                     end

  def ne r;     f_comparison(:'!=', r);                                   end

  def =~ r;     f_match(:'=~', r);                                        end

  def mne r;    f_match(:'!~', r);                                        end

  def paren();  f_build_unary(ParenthesizedExpression, current);   end

  def relop op, r
    f_build_binary_op(RelationshipExpression, op.to_sym, current, r)
  end

  def select *args
    Factory.new(build(SelectorExpression, current, *args))
  end

  # For CaseExpression, setting the default for an already build CaseExpression
  def default r
    current.addOptions(Factory.WHEN(:default, r).current)
    self
  end

  def lambda=(lambda)
    current.lambda = lambda.current
    self
  end

  # Assignment =
  def set(r)
    f_build_binary_op(AssignmentExpression, :'=', current, r)
  end

  # Assignment +=
  def plus_set(r)
    f_build_binary_op(AssignmentExpression, :'+=', current, r)
  end

  # Assignment -=
  def minus_set(r)
    f_build_binary_op(AssignmentExpression, :'-=', current, r)
  end

  def attributes(*args)
    args.each {|a| current.addAttributes(build(a)) }
    self
  end

  # Catch all delegation to current
  def method_missing(meth, *args, &block)
    if current.respond_to?(meth)
      current.send(meth, *args, &block)
    else
      super
    end
  end

  def respond_to?(meth, include_all=false)
    current.respond_to?(meth, include_all) || super
  end

  def self.record_position(o, start_locatable, end_locateable)
    new(o).record_position(start_locatable, end_locateable)
  end

  def offset
    @current.offset
  end

  def length
    @current.length
  end

  # Records the position (start -> end) and computes the resulting length.
  #
  def record_position(start_locatable, end_locatable)
    # record information directly in the Positioned object
    start_offset = start_locatable.offset
    @current.set_loc(start_offset, end_locatable ? end_locatable.offset - start_offset + end_locatable.length : start_locatable.length)
    self
  end

  # @return [Puppet::Pops::Adapters::SourcePosAdapter] with location information
  def loc()
    Adapters::SourcePosAdapter.adapt(current)
  end

  # Sets the form of the resource expression (:regular (the default), :virtual, or :exported).
  # Produces true if the expression was a resource expression, false otherwise.
  #
  def self.set_resource_form(expr, form)
    expr = expr.current if expr.instance_of?(Factory)
    # Note: Validation handles illegal combinations
    return false unless expr.is_a?(AbstractResource)
    expr.form = form
    return true
  end

  # Returns symbolic information about an expected shape of a resource expression given the LHS of a resource expr.
  #
  # * `name { }` => `:resource`,  create a resource of the given type
  # * `Name { }` => ':defaults`, set defaults for the referenced type
  # * `Name[] { }` => `:override`, overrides instances referenced by LHS
  # * _any other_ => ':error', all other are considered illegal
  #
  def self.resource_shape(expr)
    expr = expr.current if expr.instance_of?(Factory)
    case expr
    when QualifiedName
      :resource
    when QualifiedReference
      :defaults
    when AccessExpression
      # if Resource[e], then it is not resource specific
      if expr.left_expr.is_a?(QualifiedReference) && expr.left_expr.value == 'resource' && expr.keys.size == 1
        :defaults
      else
        :override
      end
    when 'class'
      :class
    else
      :error
    end
  end
  # Factory starting points

  def self.literal(o);                   new(o);                                                 end

  def self.minus(o);                     new(o).minus;                                           end

  def self.unfold(o);                    new(o).unfold;                                          end

  def self.var(o);                       new(o).var;                                             end

  def self.block(*args);                 new(BlockExpression, *args);                     end

  def self.string(*args);                new(ConcatenatedString, *args);                  end

  def self.text(o);                      new(o).text;                                            end

  def self.IF(test_e,then_e,else_e);     new(IfExpression, test_e, then_e, else_e);       end

  def self.UNLESS(test_e,then_e,else_e); new(UnlessExpression, test_e, then_e, else_e);   end

  def self.CASE(test_e,*options);        new(CaseExpression, test_e, *options);           end

  def self.WHEN(values_list, block);     new(CaseOption, values_list, block);             end

  def self.MAP(match, value);            new(SelectorEntry, match, value);                end

  def self.TYPE(name, super_name=nil);   new(CreateTypeExpression, name, super_name);     end

  def self.ATTR(name, type_expr=nil);    new(CreateAttributeExpression, name, type_expr); end

  def self.ENUM(*args);                  new(CreateEnumExpression, *args);                end

  def self.KEY_ENTRY(key, val);          new(KeyedEntry, key, val);                       end

  def self.HASH(entries);                new(LiteralHash, *entries);                      end

  def self.HEREDOC(name, expr);          new(HeredocExpression, name, expr);              end

  def self.SUBLOCATE(token, expr)        new(SubLocatedExpression, token, expr);          end

  def self.LIST(entries);                new(LiteralList, *entries);                      end

  def self.PARAM(name, expr=nil);        new(Parameter, name, expr);                      end

  def self.NODE(hosts, parent, body);    new(NodeDefinition, hosts, parent, body);        end

  def self.SITE(body);                   new(SiteDefinition, body);                       end

  # Parameters

  # Mark parameter as capturing the rest of arguments
  def captures_rest()
    current.captures_rest = true
  end

  # Set Expression that should evaluate to the parameter's type
  def type_expr(o)
    current.type_expr = to_ops(o)
  end

  # Creates a QualifiedName representation of o, unless o already represents a QualifiedName in which
  # case it is returned.
  #
  def self.fqn(o)
    o = o.current if o.instance_of?(Factory)
    o = new(QualifiedName, o) unless o.is_a? QualifiedName
    o
  end

  # Creates a QualifiedName representation of o, unless o already represents a QualifiedName in which
  # case it is returned.
  #
  def self.fqr(o)
    o = o.current if o.instance_of?(Factory)
    o = new(QualifiedReference, o) unless o.is_a? QualifiedReference
    o
  end

  def self.TEXT(expr)
    new(TextExpression, new(expr).interpolate)
  end

  # TODO_EPP
  def self.RENDER_STRING(o)
    new(RenderStringExpression, o)
  end

  def self.RENDER_EXPR(expr)
    new(RenderExpression, expr)
  end

  def self.EPP(parameters, body)
    if parameters.nil?
      params = []
      parameters_specified = false
    else
      params = parameters
      parameters_specified = true
    end
    LAMBDA(params, new(EppExpression, parameters_specified, body))
  end

  def self.RESERVED(name, future=false)
    new(ReservedWord, name, future)
  end

  # TODO: This is the same a fqn factory method, don't know if callers to fqn and QNAME can live with the
  # same result or not yet - refactor into one method when decided.
  #
  def self.QNAME(name)
    new(QualifiedName, name)
  end

  def self.NUMBER(name_or_numeric)
    if n_radix = Utils.to_n_with_radix(name_or_numeric)
      val, radix = n_radix
      if val.is_a?(Float)
        new(LiteralFloat, val)
      else
        new(LiteralInteger, val, radix)
      end
    else
      # Bad number should already have been caught by lexer - this should never happen
      raise ArgumentError, "Internal Error, NUMBER token does not contain a valid number, #{name_or_numeric}"
    end
  end

  # Convert input string to either a qualified name, a LiteralInteger with radix, or a LiteralFloat
  #
  def self.QNAME_OR_NUMBER(name)
    if n_radix = Utils.to_n_with_radix(name)
      val, radix = n_radix
      if val.is_a?(Float)
        new(LiteralFloat, val)
      else
        new(LiteralInteger, val, radix)
      end
    else
      new(QualifiedName, name)
    end
  end

  def self.QREF(name)
    new(QualifiedReference, name)
  end

  def self.VIRTUAL_QUERY(query_expr)
    new(VirtualQuery, query_expr)
  end

  def self.EXPORTED_QUERY(query_expr)
    new(ExportedQuery, query_expr)
  end

  def self.ATTRIBUTE_OP(name, op, expr)
    new(AttributeOperation, name, op, expr)
  end

  def self.ATTRIBUTES_OP(expr)
    new(AttributesOperation, expr)
  end

  def self.CALL_NAMED(name, rval_required, argument_list)
    unless name.kind_of?(PopsObject)
      name = Factory.fqn(name) unless name.instance_of?(Factory)
    end
    new(CallNamedFunctionExpression, name, rval_required, *argument_list)
  end

  def self.CALL_METHOD(functor, argument_list)
    new(CallMethodExpression, functor, true, nil, *argument_list)
  end

  def self.COLLECT(type_expr, query_expr, attribute_operations)
    new(CollectExpression, type_expr, query_expr, attribute_operations)
  end

  def self.NAMED_ACCESS(type_name, bodies)
    new(NamedAccessExpression, type_name, bodies)
  end

  def self.RESOURCE(type_name, bodies)
    new(ResourceExpression, type_name, bodies)
  end

  def self.RESOURCE_DEFAULTS(type_name, attribute_operations)
    new(ResourceDefaultsExpression, type_name, attribute_operations)
  end

  def self.RESOURCE_OVERRIDE(resource_ref, attribute_operations)
    new(ResourceOverrideExpression, resource_ref, attribute_operations)
  end

  def self.RESOURCE_BODY(resource_title, attribute_operations)
    new(ResourceBody, resource_title, attribute_operations)
  end

  def self.PROGRAM(body, definitions, locator)
    new(Program, body, definitions, locator)
  end

  # Builds a BlockExpression if args size > 1, else the single expression/value in args
  def self.block_or_expression(*args)
    if args.size > 1
      new(BlockExpression, *args)
    else
      new(args[0])
    end
  end

  def self.HOSTCLASS(name, parameters, parent, body)
    new(HostClassDefinition, name, parameters, parent, body)
  end

  def self.DEFINITION(name, parameters, body)
    new(ResourceTypeDefinition, name, parameters, body)
  end

  def self.CAPABILITY_MAPPING(kind, component, cap_name, mappings)
    new(CapabilityMapping, kind, component, cap_name, mappings)
  end

  def self.APPLICATION(name, parameters, body)
    new(Application, name, parameters, body)
  end

  def self.FUNCTION(name, parameters, body)
    new(FunctionDefinition, name, parameters, body)
  end

  def self.LAMBDA(parameters, body)
    new(LambdaExpression, parameters, body)
  end

  def self.TYPE_ASSIGNMENT(lhs, rhs)
    if lhs.current.is_a?(AccessExpression)
      new(TypeMapping, lhs, rhs)
    else
      new(TypeAlias, lhs, rhs)
    end
  end

  def self.TYPE_DEFINITION(name, parent, body)
    new(TypeDefinition, name, parent, body)
  end

  def self.nop? o
    o.nil? || o.is_a?(Nop)
  end

  STATEMENT_CALLS = {
    'require' => true,
    'realize' => true,
    'include' => true,
    'contain' => true,
    'tag'     => true,

    'debug'   => true,
    'info'    => true,
    'notice'  => true,
    'warning' => true,
    'err'     => true,

    'fail'    => true,
    'import'  => true  # discontinued, but transform it to make it call error reporting function
  }
  # Returns true if the given name is a "statement keyword" (require, include, contain,
  # error, notice, info, debug
  #
  def name_is_statement(name)
    STATEMENT_CALLS[name]
  end

  class ArgsToNonCallError < RuntimeError
    attr_reader :args, :name_expr
    def initialize(args, name_expr)
      @args = args
      @name_expr = name_expr
    end
  end

  # Transforms an array of expressions containing literal name expressions to calls if followed by an
  # expression, or expression list.
  #
  def self.transform_calls(expressions)
    expressions.reduce([]) do |memo, expr|
      expr = expr.current if expr.instance_of?(Factory)
      name = memo[-1]
      if name.is_a?(QualifiedName) && STATEMENT_CALLS[name.value]
        if expr.is_a?(Array)
          expr = expr.reject {|e| e.is_a?(Parser::LexerSupport::TokenValue) }
        else
          expr = [expr]
        end
        the_call = Factory.CALL_NAMED(name, false, expr)
        # last positioned is last arg if there are several
        record_position(the_call, name, expr.is_a?(Array) ? expr[-1]  : expr)
        memo[-1] = the_call
        if expr.is_a?(CallNamedFunctionExpression)
          # Patch statement function call to expression style
          # This is needed because it is first parsed as a "statement" and the requirement changes as it becomes
          # an argument to the name to call transform above.
          expr.rval_required = true
        end
      elsif expr.is_a?(Array)
        raise ArgsToNonCallError.new(expr, name)
      else
        memo << expr
        if expr.is_a?(CallNamedFunctionExpression)
          # Patch rvalue expression function call to statement style.
          # This is not really required but done to be AST model compliant
          expr.rval_required = false
        end
      end
      memo
    end

  end

  # Transforms a left expression followed by an untitled resource (in the form of attribute_operations)
  # @param left [Factory, Expression] the lhs followed what may be a hash
  def self.transform_resource_wo_title(left, attribute_ops, lbrace_token, rbrace_token)
    # Returning nil means accepting the given as a potential resource expression
    return nil unless attribute_ops.is_a? Array
    return nil unless left.current.is_a?(QualifiedName)
    keyed_entries = attribute_ops.map do |ao|
      return nil if ao.operator == :'+>'
      KEY_ENTRY(ao.attribute_name, ao.value_expr)
    end
    a_hash = HASH(keyed_entries)
    a_hash.record_position(lbrace_token, rbrace_token)
    result = block_or_expression(*transform_calls([left, a_hash]))
    result
  end


  # Building model equivalences of Ruby objects
  # Allows passing regular ruby objects to the factory to produce instructions
  # that when evaluated produce the same thing.

  def build_String(o)
    x = LiteralString.new
    x.value = o;
    x
  end

  def build_NilClass(o)
    x = Nop.new
    x
  end

  def build_TrueClass(o)
    x = LiteralBoolean.new
    x.value = o
    x
  end

  def build_FalseClass(o)
    x = LiteralBoolean.new
    x.value = o
    x
  end

  def build_Fixnum(o)
    x = LiteralInteger.new
    x.value = o;
    x
  end

  def build_Float(o)
    x = LiteralFloat.new
    x.value = o;
    x
  end

  def build_Regexp(o)
    x = LiteralRegularExpression.new
    x.value = o;
    x
  end

  def build_EppExpression(o, parameters_specified, body)
    o.parameters_specified = parameters_specified
    b = f_build_body(body)
    o.body = b.current if b
    o
  end

  # If building a factory, simply unwrap the model oject contained in the factory.
  def build_Factory(o)
    o.current
  end

  # Creates a String literal, unless the symbol is one of the special :undef, or :default
  # which instead creates a LiterlUndef, or a LiteralDefault.
  # Supports :undef because nil creates a no-op instruction.
  def build_Symbol(o)
    case o
    when :undef
      LiteralUndef.new
    when :default
      LiteralDefault.new
    else
      build_String(o.to_s)
    end
  end

  # Creates a LiteralList instruction from an Array, where the entries are built.
  def build_Array(o)
    x = LiteralList.new
    o.each { |v| x.addValues(build(v)) }
    x
  end

  # Create a LiteralHash instruction from a hash, where keys and values are built
  # The hash entries are added in sorted order based on key.to_s
  #
  def build_Hash(o)
    x = LiteralHash.new
    (o.sort_by {|k,v| k.to_s}).each {|k,v| x.addEntries(build(KeyedEntry.new, k, v)) }
    x
  end

  # @param rval_required [Boolean] if the call must produce a value
  def build_CallExpression(o, functor, rval_required, *args)
    o.functor_expr = to_ops(functor)
    o.rval_required = rval_required
    args.each {|x| o.addArguments(to_ops(x)) }
    o
  end

  def build_CallMethodExpression(o, functor, rval_required, lambda, *args)
    build_CallExpression(o, functor, rval_required, *args)
    o.lambda = lambda
    o
  end

  def build_CaseExpression(o, test, *args)
    o.test = build(test)
    args.each {|opt| o.addOptions(build(opt)) }
    o
  end

  def build_CaseOption(o, value_list, then_expr)
    value_list = [value_list] unless value_list.is_a? Array
    value_list.each { |v| o.addValues(build(v)) }
    b = f_build_body(then_expr)
    o.then_expr = to_ops(b) if b
    o
  end

  # Build a Class by creating an instance of it, and then calling build on the created instance
  # with the given arguments
  def build_Class(o, *args)
    build(o.new(), *args)
  end

  def interpolate_Factory(o)
    interpolate(o.current)
  end

  def interpolate_LiteralInteger(o)
    # convert number to a variable
    self.class.new(o).var
  end

  def interpolate_Object(o)
    o
  end

  def interpolate_QualifiedName(o)
    self.class.new(o).var
  end

  # rewrite left expression to variable if it is name, number, and recurse if it is an access expression
  # this is for interpolation support in new lexer (${NAME}, ${NAME[}}, ${NUMBER}, ${NUMBER[]} - all
  # other expressions requires variables to be preceded with $
  #
  def interpolate_AccessExpression(o)
    if is_interop_rewriteable?(o.left_expr)
      o.left_expr = to_ops(self.class.new(o.left_expr).interpolate)
    end
    o
  end

  def interpolate_NamedAccessExpression(o)
    if is_interop_rewriteable?(o.left_expr)
        o.left_expr = to_ops(self.class.new(o.left_expr).interpolate)
    end
    o
  end

  # Rewrite method calls on the form ${x.each ...} to ${$x.each}
  def interpolate_CallMethodExpression(o)
    if is_interop_rewriteable?(o.functor_expr)
      o.functor_expr = to_ops(self.class.new(o.functor_expr).interpolate)
    end
    o
  end

  def is_interop_rewriteable?(o)
    case o
    when AccessExpression, QualifiedName,
      NamedAccessExpression, CallMethodExpression
      true
    when LiteralInteger
      # Only decimal integers can represent variables, else it is a number
      o.radix == 10
    else
      false
    end
  end

  # Checks if the object is already a model object, or build it
  def to_ops(o, *args)
    case o
    when PopsObject
      o
    when Factory
      o.current
    else
      build(o, *args)
    end
  end

  def self.concat(*args)
    new(args.map do |e|
      e = e.current if e.is_a?(self)
      case e
      when LiteralString
        e.value
      when String
        e
      else
        raise ArgumentError, "can only concatenate strings, got #{e.class}"
      end
    end.join(''))
  end

  def to_s
    ModelTreeDumper.new.dump(self)
  end
end
end
end

