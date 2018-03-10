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
  # Shared build_visitor, since there are many instances of Factory being used

  KEY_LENGTH = 'length'.freeze
  KEY_OFFSET = 'offset'.freeze
  KEY_LOCATOR = 'locator'.freeze
  KEY_OPERATOR = 'operator'.freeze

  KEY_VALUE = 'value'.freeze
  KEY_KEYS = 'keys'.freeze
  KEY_NAME = 'name'.freeze
  KEY_BODY = 'body'.freeze
  KEY_EXPR = 'expr'.freeze
  KEY_LEFT_EXPR = 'left_expr'.freeze
  KEY_RIGHT_EXPR = 'right_expr'.freeze
  KEY_PARAMETERS = 'parameters'.freeze

  BUILD_VISITOR = Visitor.new(self, 'build')
  INFER_VISITOR = Visitor.new(self, 'infer')
  INTERPOLATION_VISITOR = Visitor.new(self, 'interpolate')

  def self.infer(o)
    if o.instance_of?(Factory)
      o
    else
      new(o)
    end
  end

  attr_reader :model_class, :unfolded

  def [](key)
    @init_hash[key]
  end

  def []=(key, value)
    @init_hash[key] = value
  end

  def all_factories(&block)
    block.call(self)
    @init_hash.each_value { |value| value.all_factories(&block) if value.instance_of?(Factory) }
  end

  def model
    if @current.nil?
      # Assign a default Locator if it's missing. Should only happen when the factory is used by other
      # means than from a parser (e.g. unit tests)
      unless @init_hash.include?(KEY_LOCATOR)
        @init_hash[KEY_LOCATOR] = Parser::Locator.locator('<no source>', 'no file')
        unless @model_class <= Program
          @init_hash[KEY_OFFSET] = 0
          @init_hash[KEY_LENGTH] = 0
        end
      end
      @current = create_model
    end
    @current
  end

  # Backward API compatibility
  alias current model

  def create_model
    @init_hash.each_pair { |key, elem| @init_hash[key] = factory_to_model(elem) }
    model_class.from_asserted_hash(@init_hash)
  end

  # Initialize a factory with a single object, or a class with arguments applied to build of
  # created instance
  #
  def initialize(o, *args)
    @init_hash = {}
    if o.instance_of?(Class)
      @model_class = o
      BUILD_VISITOR.visit_this_class(self, o, args)
    else
      INFER_VISITOR.visit_this(self, o, EMPTY_ARRAY)
    end
  end

  # Polymorphic interpolate
  def interpolate()
    INTERPOLATION_VISITOR.visit_this_class(self, @model_class, EMPTY_ARRAY)
  end

  # Building of Model classes

  def build_Application(o, n, ps, body)
    @init_hash[KEY_NAME] = n
    @init_hash[KEY_PARAMETERS] = ps
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
  end

  def build_ArithmeticExpression(o, op, a, b)
    @init_hash[KEY_OPERATOR] = op
    build_BinaryExpression(o, a, b)
  end

  def build_AssignmentExpression(o, op, a, b)
    @init_hash[KEY_OPERATOR] = op
    build_BinaryExpression(o, a, b)
  end

  def build_AttributeOperation(o, name, op, value)
    @init_hash[KEY_OPERATOR] = op
    @init_hash['attribute_name'] = name.to_s # BOOLEAN is allowed in the grammar
    @init_hash['value_expr'] = value
  end

  def build_AttributesOperation(o, value)
    @init_hash[KEY_EXPR] = value
  end

  def build_AccessExpression(o, left, keys)
    @init_hash[KEY_LEFT_EXPR] = left
    @init_hash[KEY_KEYS] = keys
  end

  def build_BinaryExpression(o, left, right)
    @init_hash[KEY_LEFT_EXPR] = left
    @init_hash[KEY_RIGHT_EXPR] = right
  end

  def build_BlockExpression(o, args)
    @init_hash['statements'] = args
  end

  def build_EppExpression(o, parameters_specified, body)
    @init_hash['parameters_specified'] = parameters_specified
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
  end

  # @param rval_required [Boolean] if the call must produce a value
  def build_CallExpression(o, functor, rval_required, args)
    @init_hash['functor_expr'] = functor
    @init_hash['rval_required'] = rval_required
    @init_hash['arguments'] = args
  end

  def build_CallMethodExpression(o, functor, rval_required, lambda, args)
    build_CallExpression(o, functor, rval_required, args)
    @init_hash['lambda'] = lambda
  end

  def build_CaseExpression(o, test, args)
    @init_hash['test'] = test
    @init_hash['options'] = args
  end

  def build_CaseOption(o, value_list, then_expr)
    value_list = [value_list] unless value_list.is_a?(Array)
    @init_hash['values'] = value_list
    b = f_build_body(then_expr)
    @init_hash['then_expr'] = b unless b.nil?
  end

  def build_CollectExpression(o, type_expr, query_expr, attribute_operations)
    @init_hash['type_expr'] = type_expr
    @init_hash['query'] = query_expr
    @init_hash['operations'] = attribute_operations
  end

  def build_ComparisonExpression(o, op, a, b)
    @init_hash[KEY_OPERATOR] = op
    build_BinaryExpression(o, a, b)
  end

  def build_ConcatenatedString(o, args)
    # Strip empty segments
    @init_hash['segments'] = args.reject { |arg| arg.model_class == LiteralString && arg['value'].empty? }
  end

  def build_HeredocExpression(o, name, expr)
    @init_hash['syntax'] = name
    @init_hash['text_expr'] = expr
  end

  # @param name [String] a valid classname
  # @param parameters [Array<Parameter>] may be empty
  # @param parent_class_name [String, nil] a valid classname referencing a parent class, optional.
  # @param body [Array<Expression>, Expression, nil] expression that constitute the body
  # @return [HostClassDefinition] configured from the parameters
  #
  def build_HostClassDefinition(o, name, parameters, parent_class_name, body)
    build_NamedDefinition(o, name, parameters, body)
    @init_hash['parent_class'] = parent_class_name unless parent_class_name.nil?
  end

  def build_ResourceOverrideExpression(o, resources, attribute_operations)
    @init_hash['resources'] = resources
    @init_hash['operations'] = attribute_operations
  end

  def build_ReservedWord(o, name, future)
    @init_hash['word'] = name
    @init_hash['future'] = future
  end

  def build_KeyedEntry(o, k, v)
    @init_hash['key'] = k
    @init_hash[KEY_VALUE] = v
  end

  def build_LiteralHash(o, keyed_entries, unfolded)
    @init_hash['entries'] = keyed_entries
    @unfolded = unfolded
  end

  def build_LiteralList(o, values)
    @init_hash['values'] = values
  end

  def build_LiteralFloat(o, val)
    @init_hash[KEY_VALUE] = val
  end

  def build_LiteralInteger(o, val, radix)
    @init_hash[KEY_VALUE] = val
    @init_hash['radix'] = radix
  end

  def build_LiteralString(o, value)
    @init_hash[KEY_VALUE] = val
  end

  def build_IfExpression(o, t, ift, els)
    @init_hash['test'] = t
    @init_hash['then_expr'] = ift
    @init_hash['else_expr'] = els
  end

  def build_MatchExpression(o, op, a, b)
    @init_hash[KEY_OPERATOR] = op
    build_BinaryExpression(o, a, b)
  end

  # Building model equivalences of Ruby objects
  # Allows passing regular ruby objects to the factory to produce instructions
  # that when evaluated produce the same thing.

  def infer_String(o)
    @model_class = LiteralString
    @init_hash[KEY_VALUE] = o
  end

  def infer_NilClass(o)
    @model_class = Nop
  end

  def infer_TrueClass(o)
    @model_class = LiteralBoolean
    @init_hash[KEY_VALUE] = o
  end

  def infer_FalseClass(o)
    @model_class = LiteralBoolean
    @init_hash[KEY_VALUE] = o
  end

  def infer_Integer(o)
    @model_class = LiteralInteger
    @init_hash[KEY_VALUE] = o
  end

  def infer_Float(o)
    @model_class = LiteralFloat
    @init_hash[KEY_VALUE] = o
  end

  def infer_Regexp(o)
    @model_class = LiteralRegularExpression
    @init_hash['pattern'] = o.inspect
    @init_hash[KEY_VALUE] = o
  end

  # Creates a String literal, unless the symbol is one of the special :undef, or :default
  # which instead creates a LiterlUndef, or a LiteralDefault.
  # Supports :undef because nil creates a no-op instruction.
  def infer_Symbol(o)
    case o
    when :undef
      @model_class = LiteralUndef
    when :default
      @model_class = LiteralDefault
    else
      infer_String(o.to_s)
    end
  end

  # Creates a LiteralList instruction from an Array, where the entries are built.
  def infer_Array(o)
    @model_class = LiteralList
    @init_hash['values'] = o.map { |e| Factory.infer(e) }
  end

  # Create a LiteralHash instruction from a hash, where keys and values are built
  # The hash entries are added in sorted order based on key.to_s
  #
  def infer_Hash(o)
    @model_class = LiteralHash
    @init_hash['entries'] = o.sort_by { |k,_| k.to_s }.map { |k, v| Factory.new(KeyedEntry, Factory.infer(k), Factory.infer(v)) }
    @unfolded = false
  end

  def f_build_body(body)
    case body
    when NilClass
      nil
    when Array
      Factory.new(BlockExpression, body)
    when Factory
      body
    else
      Factory.infer(body)
    end
  end

  def build_LambdaExpression(o, parameters, body, return_type)
    @init_hash[KEY_PARAMETERS] = parameters
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
    @init_hash['return_type'] = return_type unless return_type.nil?
  end

  def build_NamedDefinition(o, name, parameters, body)
    @init_hash[KEY_PARAMETERS] = parameters
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
    @init_hash[KEY_NAME] = name
  end

  def build_FunctionDefinition(o, name, parameters, body, return_type)
    @init_hash[KEY_PARAMETERS] = parameters
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
    @init_hash[KEY_NAME] = name
    @init_hash['return_type'] = return_type unless return_type.nil?
  end

  def build_PlanDefinition(o, name, parameters, body, return_type=nil)
    @init_hash[KEY_PARAMETERS] = parameters
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
    @init_hash[KEY_NAME] = name
    @init_hash['return_type'] = return_type unless return_type.nil?
  end

  def build_CapabilityMapping(o, kind, component, capability, mappings)
    @init_hash['kind'] = kind
    @init_hash['component'] = component
    @init_hash['capability'] = capability
    @init_hash['mappings'] = mappings
  end

  def build_NodeDefinition(o, hosts, parent, body)
    @init_hash['host_matches'] = hosts
    @init_hash['parent'] = parent unless parent.nil? # no nop here
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
  end

  def build_SiteDefinition(o, body)
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
  end

  def build_Parameter(o, name, expr)
    @init_hash[KEY_NAME] = name
    @init_hash[KEY_VALUE] = expr
  end

  def build_QualifiedReference(o, name)
    @init_hash['cased_value'] = name.to_s
  end

  def build_RelationshipExpression(o, op, a, b)
    @init_hash[KEY_OPERATOR] = op
    build_BinaryExpression(o, a, b)
  end

  def build_ResourceExpression(o, type_name, bodies)
    @init_hash['type_name'] = type_name
    @init_hash['bodies'] = bodies
  end

  def build_RenderStringExpression(o, string)
    @init_hash[KEY_VALUE] = string;
  end

  def build_ResourceBody(o, title_expression, attribute_operations)
    @init_hash['title'] = title_expression
    @init_hash['operations'] = attribute_operations
  end

  def build_ResourceDefaultsExpression(o, type_ref, attribute_operations)
    @init_hash['type_ref'] = type_ref
    @init_hash['operations'] = attribute_operations
  end

  def build_SelectorExpression(o, left, *selectors)
    @init_hash[KEY_LEFT_EXPR] = left
    @init_hash['selectors'] = selectors
  end

  # Builds a SubLocatedExpression - this wraps the expression in a sublocation configured
  # from the given token
  # A SubLocated holds its own locator that is used for subexpressions holding positions relative
  # to what it describes.
  #
  def build_SubLocatedExpression(o, token, expression)
    @init_hash[KEY_EXPR] = expression
    @init_hash[KEY_OFFSET] = token.offset
    @init_hash[KEY_LENGTH] =  token.length
    locator = token.locator
    @init_hash[KEY_LOCATOR] = locator
    @init_hash['leading_line_count'] = locator.leading_line_count
    @init_hash['leading_line_offset'] = locator.leading_line_offset
    # Index is held in sublocator's parent locator - needed to be able to reconstruct
    @init_hash['line_offsets'] = locator.locator.line_index
  end

  def build_SelectorEntry(o, matching, value)
    @init_hash['matching_expr'] = matching
    @init_hash['value_expr'] = value
  end

  def build_QueryExpression(o, expr)
    @init_hash[KEY_EXPR] = expr unless Factory.nop?(expr)
  end

  def build_TypeAlias(o, name, type_expr)
    if type_expr.model_class <= KeyedEntry
      # KeyedEntry is used for the form:
      #
      #   type Foo = Bar { ... }
      #
      # The entry contains Bar => { ... } and must be transformed into:
      #
      #   Object[{parent => Bar, ... }]
      #
      parent = type_expr['key']
      hash = type_expr['value']
      pn = parent['cased_value']
      unless pn == 'Object' || pn == 'TypeSet'
        hash['entries'] << Factory.KEY_ENTRY(Factory.QNAME('parent'), parent)
        parent = Factory.QREF('Object')
      end
      type_expr = parent.access([hash])
    elsif type_expr.model_class <= LiteralHash
      # LiteralHash is used for the form:
      #
      #   type Foo = { ... }
      #
      # The hash must be transformed into:
      #
      #   Object[{ ... }]
      #
      type_expr = Factory.QREF('Object').access([type_expr])
    end
    @init_hash['type_expr'] = type_expr
    @init_hash[KEY_NAME] = name
  end

  def build_TypeMapping(o, lhs, rhs)
    @init_hash['type_expr'] = lhs
    @init_hash['mapping_expr'] = rhs
  end

  def build_TypeDefinition(o, name, parent, body)
    b = f_build_body(body)
    @init_hash[KEY_BODY] = b unless b.nil?
    @init_hash['parent'] = parent
    @init_hash[KEY_NAME] = name
  end

  def build_UnaryExpression(o, expr)
    @init_hash[KEY_EXPR] = expr unless Factory.nop?(expr)
  end

  def build_Program(o, body, definitions, locator)
    @init_hash[KEY_BODY] = body
    # non containment
    @init_hash['definitions'] = definitions
    @init_hash[KEY_LOCATOR] = locator
  end

  def build_QualifiedName(o, name)
    @init_hash[KEY_VALUE] = name
  end

  def build_TokenValue(o)
    raise "Factory can not deal with a Lexer Token. Got token: #{o}. Probably caused by wrong index in grammar val[n]."
  end

  # Factory helpers
  def f_build_unary(klazz, expr)
    Factory.new(klazz, expr)
  end

  def f_build_binary_op(klazz, op, left, right)
    Factory.new(klazz, op, left, right)
  end

  def f_build_binary(klazz, left, right)
    Factory.new(klazz, left, right)
  end

  def f_arithmetic(op, r)
    f_build_binary_op(ArithmeticExpression, op, self, r)
  end

  def f_comparison(op, r)
    f_build_binary_op(ComparisonExpression, op, self, r)
  end

  def f_match(op, r)
    f_build_binary_op(MatchExpression, op, self, r)
  end

  # Operator helpers
  def in(r)     f_build_binary(InExpression, self, r);          end

  def or(r)     f_build_binary(OrExpression, self, r);          end

  def and(r)    f_build_binary(AndExpression, self, r);         end

  def not();    f_build_unary(NotExpression, self);             end

  def minus();  f_build_unary(UnaryMinusExpression, self);      end

  def unfold(); f_build_unary(UnfoldExpression, self);          end

  def text();   f_build_unary(TextExpression, self);            end

  def var();    f_build_unary(VariableExpression, self);        end

  def access(r); f_build_binary(AccessExpression, self, r);     end

  def dot r;    f_build_binary(NamedAccessExpression, self, r); end

  def + r;      f_arithmetic('+', r);                           end

  def - r;      f_arithmetic('-', r);                           end

  def / r;      f_arithmetic('/', r);                           end

  def * r;      f_arithmetic('*', r);                           end

  def % r;      f_arithmetic('%', r);                           end

  def << r;     f_arithmetic('<<', r);                          end

  def >> r;     f_arithmetic('>>', r);                          end

  def < r;      f_comparison('<', r);                           end

  def <= r;     f_comparison('<=', r);                          end

  def > r;      f_comparison('>', r);                           end

  def >= r;     f_comparison('>=', r);                          end

  def eq r;     f_comparison('==', r);                          end

  def ne r;     f_comparison('!=', r);                          end

  def =~ r;     f_match('=~', r);                               end

  def mne r;    f_match('!~', r);                               end

  def paren;    f_build_unary(ParenthesizedExpression, self);   end

  def relop(op, r)
    f_build_binary_op(RelationshipExpression, op, self, r)
  end

  def select(*args)
    Factory.new(SelectorExpression, self, *args)
  end

  # Same as access, but with varargs and arguments that must be inferred. For testing purposes
  def access_at(*r)
    f_build_binary(AccessExpression, self, r.map { |arg| Factory.infer(arg) })
  end

  # For CaseExpression, setting the default for an already build CaseExpression
  def default(r)
    @init_hash['options'] << Factory.WHEN(Factory.infer(:default), r)
    self
  end

  def lambda=(lambda)
    @init_hash['lambda'] = lambda
    self
  end

  # Assignment =
  def set(r)
    f_build_binary_op(AssignmentExpression, '=', self, r)
  end

  # Assignment +=
  def plus_set(r)
    f_build_binary_op(AssignmentExpression, '+=', self, r)
  end

  # Assignment -=
  def minus_set(r)
    f_build_binary_op(AssignmentExpression, '-=', self, r)
  end

  def attributes(*args)
    @init_hash['attributes'] = args
    self
  end

  def offset
    @init_hash[KEY_OFFSET]
  end

  def length
    @init_hash[KEY_LENGTH]
  end

  # Records the position (start -> end) and computes the resulting length.
  #
  def record_position(locator, start_locatable, end_locatable)
    # record information directly in the Positioned object
    start_offset = start_locatable.offset
    @init_hash[KEY_LOCATOR] = locator
    @init_hash[KEY_OFFSET] = start_offset
    @init_hash[KEY_LENGTH] = end_locatable.nil? ? start_locatable.length : end_locatable.offset + end_locatable.length - start_offset
    self
  end

  # Sets the form of the resource expression (:regular (the default), :virtual, or :exported).
  # Produces true if the expression was a resource expression, false otherwise.
  #
  def self.set_resource_form(expr, form)
    # Note: Validation handles illegal combinations
    return false unless expr.instance_of?(self) && expr.model_class <= AbstractResource
    expr['form'] = form
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
    if expr == 'class'
      :class
    elsif expr.instance_of?(self)
      mc = expr.model_class
      if mc <= QualifiedName
        :resource
      elsif mc <= QualifiedReference
        :defaults
      elsif mc <= AccessExpression
        # if Resource[e], then it is not resource specific
        lhs = expr[KEY_LEFT_EXPR]
        if lhs.model_class <= QualifiedReference && lhs[KEY_VALUE] == 'resource' && expr[KEY_KEYS].size == 1
          :defaults
        else
          :override
        end
      else
        :error
      end
    else
      :error
    end
  end

  # Factory starting points

  def self.literal(o);                   infer(o);                                       end

  def self.minus(o);                     infer(o).minus;                                 end

  def self.unfold(o);                    infer(o).unfold;                                end

  def self.var(o);                       infer(o).var;                                   end

  def self.block(*args);                 new(BlockExpression, args.map { |arg| infer(arg) }); end

  def self.string(*args);                new(ConcatenatedString, args.map { |arg| infer(arg) });           end

  def self.text(o);                      infer(o).text;                                  end

  def self.IF(test_e,then_e,else_e);     new(IfExpression, test_e, then_e, else_e);      end

  def self.UNLESS(test_e,then_e,else_e); new(UnlessExpression, test_e, then_e, else_e);  end

  def self.CASE(test_e,*options);        new(CaseExpression, test_e, options);           end

  def self.WHEN(values_list, block);     new(CaseOption, values_list, block);            end

  def self.MAP(match, value);            new(SelectorEntry, match, value);               end

  def self.KEY_ENTRY(key, val);          new(KeyedEntry, key, val);                      end

  def self.HASH(entries);                new(LiteralHash, entries, false);               end

  def self.HASH_UNFOLDED(entries);       new(LiteralHash, entries, true);                end

  def self.HEREDOC(name, expr);          new(HeredocExpression, name, expr);             end

  def self.STRING(*args);                new(ConcatenatedString, args);                  end

  def self.SUBLOCATE(token, expr)        new(SubLocatedExpression, token, expr);         end

  def self.LIST(entries);                new(LiteralList, entries);                      end

  def self.PARAM(name, expr=nil);        new(Parameter, name, expr);                     end

  def self.NODE(hosts, parent, body);    new(NodeDefinition, hosts, parent, body);       end

  def self.SITE(body);                   new(SiteDefinition, body);                      end

  # Parameters

  # Mark parameter as capturing the rest of arguments
  def captures_rest
    @init_hash['captures_rest'] = true
  end

  # Set Expression that should evaluate to the parameter's type
  def type_expr(o)
    @init_hash['type_expr'] = o
  end

  # Creates a QualifiedName representation of o, unless o already represents a QualifiedName in which
  # case it is returned.
  #
  def self.fqn(o)
    o.instance_of?(Factory) && o.model_class <= QualifiedName ? self : new(QualifiedName, o)
  end

  # Creates a QualifiedName representation of o, unless o already represents a QualifiedName in which
  # case it is returned.
  #
  def self.fqr(o)
    o.instance_of?(Factory) && o.model_class <= QualifiedReference ? self : new(QualifiedReference, o)
  end

  def self.TEXT(expr)
    new(TextExpression, infer(expr).interpolate)
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
    LAMBDA(params, new(EppExpression, parameters_specified, body), nil)
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
      #TRANSLATORS 'NUMBER' refers to a method name and the 'name_or_numeric' was the passed in value and should not be translated
      raise ArgumentError, _("Internal Error, NUMBER token does not contain a valid number, %{name_or_numeric}") %
          { name_or_numeric: name_or_numeric }
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

  def self.ARGUMENTS(args, arg)
    if !args.empty? && arg.model_class <= LiteralHash && arg.unfolded
      last = args[args.size() - 1]
      if last.model_class <= LiteralHash && last.unfolded
        last['entries'].concat(arg['entries'])
        return args
      end
    end
    args.push(arg)
  end

  def self.ATTRIBUTE_OP(name, op, expr)
    new(AttributeOperation, name, op, expr)
  end

  def self.ATTRIBUTES_OP(expr)
    new(AttributesOperation, expr)
  end

  # Same as CALL_NAMED but with inference and varargs (for testing purposes)
  def self.call_named(name, rval_required, *argument_list)
    new(CallNamedFunctionExpression, fqn(name), rval_required, argument_list.map { |arg| infer(arg) })
  end

  def self.CALL_NAMED(name, rval_required, argument_list)
    new(CallNamedFunctionExpression, name, rval_required, argument_list)
  end

  def self.CALL_METHOD(functor, argument_list)
    new(CallMethodExpression, functor, true, nil, argument_list)
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
  def self.block_or_expression(args, left_brace = nil, right_brace = nil)
    if args.size > 1
      block_expr = new(BlockExpression, args)

      # If given a left and right brace position, use those
      # otherwise use the first and last element of the block
      if !left_brace.nil? && !right_brace.nil?
        block_expr.record_position(args.first[KEY_LOCATOR], left_brace, right_brace)
      else
        block_expr.record_position(args.first[KEY_LOCATOR], args.first, args.last)
      end

      block_expr
    else
      args[0]
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

  def self.PLAN(name, parameters, body)
    new(PlanDefinition, name, parameters, body, nil)
  end

  def self.FUNCTION(name, parameters, body, return_type)
    new(FunctionDefinition, name, parameters, body, return_type)
  end

  def self.LAMBDA(parameters, body, return_type)
    new(LambdaExpression, parameters, body, return_type)
  end

  def self.TYPE_ASSIGNMENT(lhs, rhs)
    if lhs.model_class <= AccessExpression
      new(TypeMapping, lhs, rhs)
    else
      new(TypeAlias, lhs['cased_value'], rhs)
    end
  end

  def self.TYPE_DEFINITION(name, parent, body)
    new(TypeDefinition, name, parent, body)
  end

  def self.nop? o
    o.nil? || o.instance_of?(Factory) && o.model_class <= Nop
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
    'import'  => true,  # discontinued, but transform it to make it call error reporting function
    'break'   => true,
    'next'    => true,
    'return'  => true
  }.freeze

  # Returns true if the given name is a "statement keyword" (require, include, contain,
  # error, notice, info, debug
  #
  def self.name_is_statement?(name)
    STATEMENT_CALLS.include?(name)
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
      name = memo[-1]
      if name.instance_of?(Factory) && name.model_class <= QualifiedName && name_is_statement?(name[KEY_VALUE])
        if expr.is_a?(Array)
          expr = expr.reject { |e| e.is_a?(Parser::LexerSupport::TokenValue) }
        else
          expr = [expr]
        end
        the_call = self.CALL_NAMED(name, false, expr)
        # last positioned is last arg if there are several
        the_call.record_position(name[KEY_LOCATOR], name, expr[-1])
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
        if expr.model_class <= CallNamedFunctionExpression
          # Patch rvalue expression function call to statement style.
          # This is not really required but done to be AST model compliant
          expr['rval_required'] = false
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
    return nil unless left.model_class <= QualifiedName
    keyed_entries = attribute_ops.map do |ao|
      return nil if ao[KEY_OPERATOR] == '+>'
      KEY_ENTRY(infer(ao['attribute_name']), ao['value_expr'])
    end
    a_hash = HASH(keyed_entries)
    a_hash.record_position(left[KEY_LOCATOR], lbrace_token, rbrace_token)
    result = block_or_expression(transform_calls([left, a_hash]))
    result
  end

  def interpolate_Factory(c)
    self
  end

  def interpolate_LiteralInteger(c)
    # convert number to a variable
    self.var
  end

  def interpolate_Object(c)
    self
  end

  def interpolate_QualifiedName(c)
    self.var
  end

  # rewrite left expression to variable if it is name, number, and recurse if it is an access expression
  # this is for interpolation support in new lexer (${NAME}, ${NAME[}}, ${NUMBER}, ${NUMBER[]} - all
  # other expressions requires variables to be preceded with $
  #
  def interpolate_AccessExpression(c)
    lhs = @init_hash[KEY_LEFT_EXPR]
    if is_interop_rewriteable?(lhs)
      @init_hash[KEY_LEFT_EXPR] = lhs.interpolate
    end
    self
  end

  def interpolate_NamedAccessExpression(c)
    lhs = @init_hash[KEY_LEFT_EXPR]
    if is_interop_rewriteable?(lhs)
      @init_hash[KEY_LEFT_EXPR] = lhs.interpolate
    end
    self
  end

  # Rewrite method calls on the form ${x.each ...} to ${$x.each}
  def interpolate_CallMethodExpression(c)
    functor_expr = @init_hash['functor_expr']
    if is_interop_rewriteable?(functor_expr)
      @init_hash['functor_expr'] = functor_expr.interpolate
    end
    self
  end

  def is_interop_rewriteable?(o)
    mc = o.model_class
    if mc <= AccessExpression || mc <= QualifiedName || mc <= NamedAccessExpression || mc <= CallMethodExpression
      true
    elsif mc <= LiteralInteger
      # Only decimal integers can represent variables, else it is a number
      o['radix'] == 10
    else
      false
    end
  end

  def self.concat(*args)
    result = ''
    args.each do |e|
      if e.instance_of?(Factory) && e.model_class <= LiteralString
        result << e[KEY_VALUE]
      elsif e.is_a?(String)
        result << e
      else
        raise ArgumentError, _("can only concatenate strings, got %{class_name}") % { class_name: e.class }
      end
    end
    infer(result)
  end

  def to_s
    "Factory for #{@model_class}"
  end

  def factory_to_model(value)
    if value.instance_of?(Factory)
      value.contained_current(self)
    elsif value.instance_of?(Array)
      value.each_with_index { |el, idx| value[idx] = el.contained_current(self) if el.instance_of?(Factory) }
    else
      value
    end
  end

  def contained_current(container)
    if @current.nil?
      unless @init_hash.include?(KEY_LOCATOR)
        @init_hash[KEY_LOCATOR] = container[KEY_LOCATOR]
        @init_hash[KEY_OFFSET] = container[KEY_OFFSET] || 0
        @init_hash[KEY_LENGTH] = 0
      end
      @current = create_model
    end
    @current
  end
end
end
end
