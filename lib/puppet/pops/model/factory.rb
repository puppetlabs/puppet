# Factory is a helper class that makes construction of a Pops Model
# much more convenient. It can be viewed as a small internal DSL for model
# constructions.
# For usage see tests using the factory.
#
# @todo All those uppercase methods ... they look bad in one way, but stand out nicely in the grammar...
#   decide if they should change into lower case names (some of the are lower case)...
#
class Puppet::Pops::Model::Factory
  Model = Puppet::Pops::Model

  attr_accessor :current

  # Shared build_visitor, since there are many instances of Factory being used
  @@build_visitor = Puppet::Pops::Visitor.new(self, "build")
  # Initialize a factory with a single object, or a class with arguments applied to build of
  # created instance
  #
  def initialize popsobj, *args
    @current = to_ops(popsobj, *args)
  end

  # Polymorphic build
  def build(o, *args)
    begin
      @@build_visitor.visit_this(self, o, *args)
    rescue =>e
      # require 'debugger'; debugger # enable this when in trouble...
      raise e
    end
  end

  # Building of Model classes

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

  def build_AccessExpression(o, left, *keys)
    o.left_expr = to_ops(left)
    keys.each {|expr| o.addKeys(to_ops(expr)) }
    o
  end

  def build_BinaryExpression(o, left, right)
    o.left_expr = to_ops(left)
    o.right_expr = to_ops(right)
    o
  end

  def build_BlockExpression(o, *args)
    args.each {|expr| o.addStatements(to_ops(expr)) }
    o
  end

  def build_CollectExpression(o, type_expr, query_expr, attribute_operations)
    o.type_expr = to_ops(type_expr)
    o.query = build(query_expr)
    attribute_operations.each {|op| o.addOperations(build(op)) }
    o
  end

  def build_ComparisonExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  def build_ConcatenatedString(o, *args)
    args.each {|expr| o.addSegments(build(expr)) }
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

  # @param name [String] a valid classname
  # @param parameters [Array<Model::Parameter>] may be empty
  # @param parent_class_name [String, nil] a valid classname referencing a parent class, optional.
  # @param body [Array<Expression>, Expression, nil] expression that constitute the body
  # @return [Model::HostClassDefinition] configured from the parameters
  #
  def build_HostClassDefinition(o, name, parameters, parent_class_name, body)
    build_NamedDefinition(o, name, parameters, body)
    o.parent_class = parent_class_name if parent_class_name
    o
  end

  #  # @param name [String] a valid classname
  #  # @param parameters [Array<Model::Parameter>] may be empty
  #  # @param body [Array<Expression>, Expression, nil] expression that constitute the body
  #  # @return [Model::HostClassDefinition] configured from the parameters
  #  #
  #  def build_ResourceTypeDefinition(o, name, parameters, body)
  #    build_NamedDefinition(o, name, parameters, body)
  #    o.name = name
  #    parameters.each {|p| o.addParameters(build(p)) }
  #    b = f_build_body(body)
  #    o.body = b.current if b
  #    o
  #  end

  def build_ResourceOverrideExpression(o, resources, attribute_operations)
    o.resources = build(resources)
    attribute_operations.each {|ao| o.addOperations(build(ao)) }
    o
  end

  def build_KeyedEntry(o, k, v)
    o.key = build(k)
    o.value = build(v)
    o
  end

  def build_LiteralHash(o, *keyed_entries)
    keyed_entries.each {|entry| o.addEntries build(entry) }
    o
  end

  def build_LiteralList(o, *values)
    values.each {|v| o.addValues build(v) }
    o
  end

  def build_LiteralNumber(o, val, radix)
    o.value = val
    o.radix = radix
    o
  end

  def build_InstanceReferences(o, type_name, name_expressions)
    o.type_name = build(type_name)
    name_expressions.each {|n| o.addNames(build(n)) }
    o
  end

  def build_ImportExpression(o, files)
    # The argument files has already been built
    files.each {|f| o.addFiles(to_ops(f)) }
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
  # @param body [nil] unchanged, produces nil
  # @param body [Array<Expression>] turns into a BlockExpression
  # @param body [Expression] produces the given expression
  # @param body [Object] produces the result of calling #build with body as argument
  def f_build_body(body)
    case body
    when NilClass
      nil
    when Array
      Puppet::Pops::Model::Factory.new(Model::BlockExpression, *body)
    else
      build(body)
    end
  end

  def build_Definition(o, parameters, body)
    parameters.each {|p| o.addParameters(build(p)) }
    b = f_build_body(body)
    o.body = b.current if b
    o
  end

  def build_NamedDefinition(o, name, parameters, body)
    build_Definition(o, parameters, body)
    o.name = name
    o
  end

  # @param o [Model::NodeDefinition]
  # @param hosts [Array<Expression>] host matches
  # @param parent [Expression] parent node matcher
  # @param body [Object] see {#f_build_body}
  def build_NodeDefinition(o, hosts, parent, body)
    hosts.each {|h| o.addHost_matches(build(h)) }
    o.parent = build(parent) if parent # no nop here
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
    o.value = name.to_s.downcase
    o
  end

  def build_RelationshipExpression(o, op, a, b)
    o.operator = op
    build_BinaryExpression(o, a, b)
  end

  def build_ResourceExpression(o, type_name, bodies)
    o.type_name = build(type_name)
    bodies.each {|b| o.addBodies(build(b)) }
    o
  end

  def build_ResourceBody(o, title_expression, attribute_operations)
    o.title = build(title_expression)
    attribute_operations.each {|ao| o.addOperations(build(ao)) }
    o
  end

  def build_ResourceDefaultsExpression(o, type_ref, attribute_operations)
    o.type_ref = build(type_ref)
    attribute_operations.each {|ao| o.addOperations(build(ao)) }
    o
  end

  def build_SelectorExpression(o, left, *selectors)
    o.left_expr = to_ops(left)
    selectors.each {|s| o.addSelectors(build(s)) }
    o
  end

  def build_SelectorEntry(o, matching, value)
    o.matching_expr = build(matching)
    o.value_expr = build(value)
    o
  end

  def build_QueryExpression(o, expr)
    ops = to_ops(expr)
    o.expr = ops unless Puppet::Pops::Model::Factory.nop? ops
    o
  end

  def build_UnaryExpression(o, expr)
    ops = to_ops(expr)
    o.expr = ops unless Puppet::Pops::Model::Factory.nop? ops
    o
  end

  def build_QualifiedName(o, name)
    o.value = name.to_s
    o
  end

  # Puppet::Pops::Model::Factory helpers
  def f_build_unary(klazz, expr)
    Puppet::Pops::Model::Factory.new(build(klazz.new, expr))
  end

  def f_build_binary_op(klazz, op, left, right)
    Puppet::Pops::Model::Factory.new(build(klazz.new, op, left, right))
  end

  def f_build_binary(klazz, left, right)
    Puppet::Pops::Model::Factory.new(build(klazz.new, left, right))
  end

  def f_build_vararg(klazz, left, *arg)
    Puppet::Pops::Model::Factory.new(build(klazz.new, left, *arg))
  end

  def f_arithmetic(op, r)
    f_build_binary_op(Model::ArithmeticExpression, op, current, r)
  end

  def f_comparison(op, r)
    f_build_binary_op(Model::ComparisonExpression, op, current, r)
  end

  def f_match(op, r)
    f_build_binary_op(Model::MatchExpression, op, current, r)
  end

  # Operator helpers
  def in(r)     f_build_binary(Model::InExpression, current, r);          end

  def or(r)     f_build_binary(Model::OrExpression, current, r);          end

  def and(r)    f_build_binary(Model::AndExpression, current, r);         end

  def not();    f_build_unary(Model::NotExpression, self);                end

  def minus();  f_build_unary(Model::UnaryMinusExpression, self);         end

  def text();   f_build_unary(Model::TextExpression, self);               end

  def var();    f_build_unary(Model::VariableExpression, self);           end

  def [](*r);   f_build_vararg(Model::AccessExpression, current, *r);     end

  def dot r;    f_build_binary(Model::NamedAccessExpression, current, r); end

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

  def paren();  f_build_unary(Model::ParenthesizedExpression, current);   end

  def relop op, r
    f_build_binary_op(Model::RelationshipExpression, op.to_sym, current, r)
  end

  def select *args
    Puppet::Pops::Model::Factory.new(build(Model::SelectorExpression, current, *args))
  end

  # For CaseExpression, setting the default for an already build CaseExpression
  def default r
    current.addOptions(Puppet::Pops::Model::Factory.WHEN(:default, r).current)
    self
  end

  def lambda=(lambda)
    current.lambda = lambda.current
    self
  end

  # Assignment =
  def set(r)
    f_build_binary_op(Model::AssignmentExpression, :'=', current, r)
  end

  # Assignment +=
  def plus_set(r)
    f_build_binary_op(Model::AssignmentExpression, :'+=', current, r)
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

  def respond_to?(meth)
    current.respond_to?(meth) || super
  end

  # Records the position (start -> end) and computes the resulting length.
  #
  def record_position(start_pos, end_pos)
    Puppet::Pops::Adapters::SourcePosAdapter.adapt(current) do |a|
      a.line   = start_pos.line
      a.offset = start_pos.offset
      a.pos    = start_pos.pos
      a.length = start_pos.length
      if(end_pos.offset && end_pos.length)
        a.length = end_pos.offset + end_pos.length - start_pos.offset
      end
    end
    self
  end

  # Records the origin file of an element
  # Does nothing if file is nil.
  #
  # @param file [String,nil] the file/path to the origin, may contain URI scheme of file: or some other URI scheme
  # @returns [Factory] returns self
  #
  def record_origin(file)
    return self unless file
    Puppet::Pops::Adapters::OriginAdapter.adapt(current) do |a|
       a.origin = file
    end
    self
  end

  # @return [Puppet::Pops::Adapters::SourcePosAdapter] with location information
  def loc()
    Puppet::Pops::Adapters::SourcePosAdapter.adapt(current)
  end

  # Returns documentation string, or nil if not available
  # @return [String, nil] associated documentation if available
  def doc()
    a = Puppet::Pops::Adapters::SourcePosAdapter.adapt(current)
    return a.documentation if a
    nil
  end

  def doc=(doc_string)
    a = Puppet::Pops::Adapters::SourcePosAdapter.adapt(current)
    a.documentation = doc_string
  end

  # Returns symbolic information about an expected share of a resource expression given the LHS of a resource expr.
  #
  # * `name { }` => `:resource`,  create a resource of the given type
  # * `Name { }` => ':defaults`, set defauls for the referenced type
  # * `Name[] { }` => `:override`, ioverrides nstances referenced by LHS
  # * _any other_ => ':error', all other are considered illegal
  #
  def self.resource_shape(expr)
    expr = expr.current if expr.is_a?(Puppet::Pops::Model::Factory)
    case expr
    when Model::QualifiedName
      :resource
    when Model::QualifiedReference
      :defaults
    when Model::AccessExpression
      :override
    when 'class'
      :class
    else
      :error
    end
  end
  # Factory starting points

  def self.literal(o);                   new(o);                                                 end

  def self.minus(o);                     new(o).minus;                                           end

  def self.var(o);                       new(o).var;                                             end

  def self.block(*args);                 new(Model::BlockExpression, *args);                     end

  def self.string(*args);                new(Model::ConcatenatedString, *args);                  end

  def self.text(o);                      new(o).text;                                            end

  def self.IF(test_e,then_e,else_e);     new(Model::IfExpression, test_e, then_e, else_e);       end

  def self.UNLESS(test_e,then_e,else_e); new(Model::UnlessExpression, test_e, then_e, else_e);   end

  def self.CASE(test_e,*options);        new(Model::CaseExpression, test_e, *options);           end

  def self.WHEN(values_list, block);     new(Model::CaseOption, values_list, block);             end

  def self.MAP(match, value);            new(Model::SelectorEntry, match, value);                end

  def self.TYPE(name, super_name=nil);   new(Model::CreateTypeExpression, name, super_name);     end

  def self.ATTR(name, type_expr=nil);    new(Model::CreateAttributeExpression, name, type_expr); end

  def self.ENUM(*args);                  new(Model::CreateEnumExpression, *args);                end

  def self.KEY_ENTRY(key, val);          new(Model::KeyedEntry, key, val);                       end

  def self.HASH(entries);                new(Model::LiteralHash, *entries);                      end

  def self.LIST(entries);                new(Model::LiteralList, *entries);                      end

  def self.PARAM(name, expr=nil);        new(Model::Parameter, name, expr);                      end

  def self.NODE(hosts, parent, body);    new(Model::NodeDefinition, hosts, parent, body);        end

  # Creates a QualifiedName representation of o, unless o already represents a QualifiedName in which
  # case it is returned.
  #
  def self.fqn(o)
    o = o.current if o.is_a?(Puppet::Pops::Model::Factory)
    o = new(Model::QualifiedName, o) unless o.is_a? Model::QualifiedName
    o
  end

  # Creates a QualifiedName representation of o, unless o already represents a QualifiedName in which
  # case it is returned.
  #
  def self.fqr(o)
    o = o.current if o.is_a?(Puppet::Pops::Model::Factory)
    o = new(Model::QualifiedReference, o) unless o.is_a? Model::QualifiedReference
    o
  end

  def self.TEXT(expr)
    new(Model::TextExpression, expr)
  end

  # TODO: This is the same a fqn factory method, don't know if callers to fqn and QNAME can live with the
  # same result or not yet - refactor into one method when decided.
  #
  def self.QNAME(name)
    new(Model::QualifiedName, name)
  end

  # Convert input string to either a qualified name, or a LiteralNumber with radix
  #
  def self.QNAME_OR_NUMBER(name)
    if n_radix = Puppet::Pops::Utils.to_n_with_radix(name)
      new(Model::LiteralNumber, *n_radix)
    else
      new(Model::QualifiedName, name)
    end
  end

  def self.QREF(name)
    new(Model::QualifiedReference, name)
  end

  def self.VIRTUAL_QUERY(query_expr)
    new(Model::VirtualQuery, query_expr)
  end

  def self.EXPORTED_QUERY(query_expr)
    new(Model::ExportedQuery, query_expr)
  end

  # Used by regular grammar, egrammar creates an AccessExpression instead, and evaluation determines
  # if access is to instances or something else.
  #
  def self.INSTANCE(type_name, name_expressions)
    new(Model::InstanceReferences, type_name, name_expressions)
  end

  def self.ATTRIBUTE_OP(name, op, expr)
    new(Model::AttributeOperation, name, op, expr)
  end

  def self.CALL_NAMED(name, rval_required, argument_list)
    unless name.kind_of?(Model::PopsObject)
      name = Puppet::Pops::Model::Factory.fqn(name) unless name.is_a?(Puppet::Pops::Model::Factory)
    end
    new(Model::CallNamedFunctionExpression, name, rval_required, *argument_list)
  end

  def self.CALL_METHOD(functor, argument_list)
    new(Model::CallMethodExpression, functor, true, nil, *argument_list)
  end

  def self.COLLECT(type_expr, query_expr, attribute_operations)
    new(Model::CollectExpression, Puppet::Pops::Model::Factory.fqr(type_expr), query_expr, attribute_operations)
  end

  def self.IMPORT(files)
    new(Model::ImportExpression, files)
  end

  def self.NAMED_ACCESS(type_name, bodies)
    new(Model::NamedAccessExpression, type_name, bodies)
  end

  def self.RESOURCE(type_name, bodies)
    new(Model::ResourceExpression, type_name, bodies)
  end

  def self.RESOURCE_DEFAULTS(type_name, attribute_operations)
    new(Model::ResourceDefaultsExpression, type_name, attribute_operations)
  end

  def self.RESOURCE_OVERRIDE(resource_ref, attribute_operations)
    new(Model::ResourceOverrideExpression, resource_ref, attribute_operations)
  end

  def self.RESOURCE_BODY(resource_title, attribute_operations)
    new(Model::ResourceBody, resource_title, attribute_operations)
  end

  # Builds a BlockExpression if args size > 1, else the single expression/value in args
  def self.block_or_expression(*args)
    if args.size > 1
      new(Model::BlockExpression, *args)
    else
      new(args[0])
    end
  end

  def self.HOSTCLASS(name, parameters, parent, body)
    new(Model::HostClassDefinition, name, parameters, parent, body)
  end

  def self.DEFINITION(name, parameters, body)
    new(Model::ResourceTypeDefinition, name, parameters, body)
  end

  def self.LAMBDA(parameters, body)
    new(Model::LambdaExpression, parameters, body)
  end

  def self.nop? o
    o.nil? || o.is_a?(Puppet::Pops::Model::Nop)
  end

  # Transforms an array of expressions containing literal name expressions to calls if followed by an
  # expression, or expression list. Also transforms a "call" to `import` into an ImportExpression.
  #
  def self.transform_calls(expressions)
    expressions.reduce([]) do |memo, expr|
      expr = expr.current if expr.is_a?(Puppet::Pops::Model::Factory)
      name = memo[-1]
      if name.is_a? Model::QualifiedName
        if name.value() == 'import'
          memo[-1] = Puppet::Pops::Model::Factory.IMPORT(expr.is_a?(Array) ? expr : [expr])
        else
          memo[-1] = Puppet::Pops::Model::Factory.CALL_NAMED(name, false, expr.is_a?(Array) ? expr : [expr])
        end
      else
        memo << expr
      end
      if expr.is_a?(Model::CallNamedFunctionExpression)
        # patch expression function call to statement style
        # TODO: This is kind of meaningless, but to make it compatible...
        expr.rval_required = false
      end
      memo
    end

  end

  # Building model equivalences of Ruby objects
  # Allows passing regular ruby objects to the factory to produce instructions
  # that when evaluated produce the same thing.

  def build_String(o)
    x = Model::LiteralString.new
    x.value = o;
    x
  end

  def build_NilClass(o)
    x = Model::Nop.new
    x
  end

  def build_TrueClass(o)
    x = Model::LiteralBoolean.new
    x.value = o
    x
  end

  def build_FalseClass(o)
    x = Model::LiteralBoolean.new
    x.value = o
    x
  end

  def build_Fixnum(o)
    x = Model::LiteralNumber.new
    x.value = o;
    x
  end

  def build_Float(o)
    x = Model::LiteralNumber.new
    x.value = o;
    x
  end

  def build_Regexp(o)
    x = Model::LiteralRegularExpression.new
    x.value = o;
    x
  end

  # If building a factory, simply unwrap the model oject contained in the factory.
  def build_Factory(o)
    o.current
  end

  # Creates a String literal, unless the symbol is one of the special :undef, or :default
  # which instead creates a LiterlUndef, or a LiteralDefault.
  def build_Symbol(o)
    case o
    when :undef
      Model::LiteralUndef.new
    when :default
      Model::LiteralDefault.new
    else
      build_String(o.to_s)
    end
  end

  # Creates a LiteralList instruction from an Array, where the entries are built.
  def build_Array(o)
    x = Model::LiteralList.new
    o.each { |v| x.addValues(build(v)) }
    x
  end

  # Create a LiteralHash instruction from a hash, where keys and values are built
  # The hash entries are added in sorted order based on key.to_s
  #
  def build_Hash(o)
    x = Model::LiteralHash.new
    (o.sort_by {|k,v| k.to_s}).each {|k,v| x.addEntries(build(Model::KeyedEntry.new, k, v)) }
    x
  end

  # @param rval_required [Boolean] if the call must produce a value
  def build_CallExpression(o, functor, rval_required, *args)
    o.functor_expr = to_ops(functor)
    o.rval_required = rval_required
    args.each {|x| o.addArguments(to_ops(x)) }
    o
  end

  #  # @param rval_required [Boolean] if the call must produce a value
  #  def build_CallNamedFunctionExpression(o, name, rval_required, *args)
  #    build_CallExpression(o, name, rval_required, *args)
  ##    o.functor_expr = build(name)
  ##    o.rval_required = rval_required
  ##    args.each {|x| o.addArguments(build(x)) }
  #    o
  #  end

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

  # Checks if the object is already a model object, or build it
  def to_ops(o, *args)
    if o.kind_of?(Model::PopsObject)
      o
    else
      build(o, *args)
    end
  end
end
