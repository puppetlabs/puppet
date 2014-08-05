require 'puppet/parser/ast'

# The receiver of `import(file)` calls; once per imported file, or nil if imports are ignored
#
# Transforms a Pops::Model to classic Puppet AST.
# TODO: Documentation is currently skipped completely (it is only used for Rdoc)
#
class Puppet::Pops::Model::AstTransformer
  AST = Puppet::Parser::AST
  Model = Puppet::Pops::Model

  attr_reader :importer
  def initialize(source_file = "unknown-file", importer=nil)
    @@transform_visitor ||= Puppet::Pops::Visitor.new(nil,"transform",0,0)
    @@query_transform_visitor ||= Puppet::Pops::Visitor.new(nil,"query",0,0)
    @@hostname_transform_visitor ||= Puppet::Pops::Visitor.new(nil,"hostname",0,0)
    @importer = importer
    @source_file = source_file
  end

  # Initialize klass from o (location) and hash (options to created instance).
  # The object o is used to compute a source location. It may be nil. Source position is merged into
  # the given options (non surgically). If o is non-nil, the first found source position going up
  # the containment hierarchy is set. I.e. callers should pass nil if a source position is not wanted
  # or known to be unobtainable for the object.
  #
  # @param o [Object, nil] object from which source position / location is obtained, may be nil
  # @param klass [Class<Puppet::Parser::AST>] the ast class to create an instance of
  # @param hash [Hash] hash with options for the class to create
  #
  def ast(o, klass, hash={})
    # create and pass hash with file and line information
    klass.new(merge_location(hash, o))
  end

  # THIS IS AN EXPENSIVE OPERATION
  # The 3x AST requires line, pos etc. to be recorded directly in the AST nodes and this information
  # must be computed.
  # (Newer implementation only computes the information that is actually needed; typically when raising an
  # exception).
  #
  def merge_location(hash, o)
    if o
      pos = {}
      source_pos = Puppet::Pops::Utils.find_closest_positioned(o)
      if source_pos
        pos[:line] = source_pos.line
        pos[:pos]  = source_pos.pos
      end
      pos[:file] = @source_file if @source_file
      hash = hash.merge(pos)
    end
    hash
  end

  # Transforms pops expressions into AST 3.1 statements/expressions
  def transform(o)
    begin
    @@transform_visitor.visit_this(self,o)
    rescue StandardError => e
      loc_data = {}
      merge_location(loc_data, o)
      raise Puppet::ParseError.new("Error while transforming to Puppet 3 AST: #{e.message}", 
        loc_data[:file], loc_data[:line], loc_data[:pos], e)
    end
  end

  # Transforms pops expressions into AST 3.1 query expressions
  def query(o)
    @@query_transform_visitor.visit_this(self, o)
  end

  # Transforms pops expressions into AST 3.1 hostnames
  def hostname(o)
    @@hostname_transform_visitor.visit_this(self, o)
  end

  def transform_LiteralFloat(o)
    # Numbers are Names in the AST !! (Name a.k.a BareWord)
    ast o, AST::Name, :value => o.value.to_s
  end

  def transform_LiteralInteger(o)
    s = case o.radix
    when 10
      o.value.to_s
    when 8
      "0%o" % o.value
    when 16
      "0x%X" % o.value
    else
      "bad radix:" + o.value.to_s
    end

    # Numbers are Names in the AST !! (Name a.k.a BareWord)
    ast o, AST::Name, :value => s
  end

  # Transforms all literal values to string (override for those that should not be AST::String)
  #
  def transform_LiteralValue(o)
    ast o, AST::String, :value => o.value.to_s
  end

  def transform_LiteralBoolean(o)
    ast o, AST::Boolean, :value => o.value
  end

  def transform_Factory(o)
    transform(o.current)
  end

  def transform_ArithmeticExpression(o)
    ast o, AST::ArithmeticOperator2, :lval => transform(o.left_expr), :rval=>transform(o.right_expr),
    :operator => o.operator.to_s
  end

  def transform_Array(o)
    ast nil, AST::ASTArray, :children => o.collect {|x| transform(x) }
  end

  # Puppet AST only allows:
  # * variable[expression] => Hasharray Access
  # * NAME [expressions] => Resource Reference(s)
  # * type [epxressions] => Resource Reference(s)
  # * HashArrayAccesses[expression] => HasharrayAccesses
  #
  # i.e. it is not possible to do `func()[3]`, `[1,2,3][$x]`, `{foo=>10, bar=>20}[$x]` etc. since
  # LHS is not an expression
  #
  # Validation for 3.x semantics should validate the illegal cases. This transformation may fail,
  # or ignore excess information if the expressions are not correct.
  # This means that the transformation does not have to evaluate the lhs to detect the target expression.
  #
  # Hm, this seems to have changed, the LHS (variable) is evaluated if evaluateable, else it is used as is.
  #
  def transform_AccessExpression(o)
    case o.left_expr
    when Model::QualifiedName
      ast o, AST::ResourceReference, :type => o.left_expr.value, :title => transform(o.keys)

    when Model::QualifiedReference
      ast o, AST::ResourceReference, :type => o.left_expr.value, :title => transform(o.keys)

    when Model::VariableExpression
      ast o, AST::HashOrArrayAccess, :variable => transform(o.left_expr), :key => transform(o.keys()[0])

    else
      ast o, AST::HashOrArrayAccess, :variable => transform(o.left_expr), :key => transform(o.keys()[0])
    end
  end

  # Puppet AST has a complicated structure
  # LHS can not be an expression, it must be a type (which is downcased).
  # type = a downcased QualifiedName
  #
  def transform_CollectExpression(o)
    raise "LHS is not a type" unless o.type_expr.is_a? Model::QualifiedReference
    type = o.type_expr.value().downcase()
    args = { :type => type }

    # This somewhat peculiar encoding is used by the 3.1 AST.
    query = transform(o.query)
    if query.is_a? Symbol
      args[:form] =  query
    else
      args[:form] = query.form
      args[:query] = query
      query.type = type
    end

    if o.operations.size > 0
      args[:override] = transform(o.operations)
    end
    ast o, AST::Collection, args
  end

  def transform_EppExpression(o)
    # TODO: Not supported in 3x TODO_EPP
    parameters = o.parameters.collect {|p| transform(p) }
    args = { :parameters => parameters }
    args[:children] = transform(o.body) unless is_nop?(o.body)
    Puppet::Parser::AST::Epp.new(merge_location(args, o))
  end

  def transform_ExportedQuery(o)
    if is_nop?(o.expr)
      result = :exported
    else
      result = query(o.expr)
      result.form = :exported
    end
    result
  end

  def transform_VirtualQuery(o)
    if is_nop?(o.expr)
      result = :virtual
    else
      result = query(o.expr)
      result.form = :virtual
    end
    result
  end

  # Ensures transformation fails if a 3.1 non supported object is encountered in a query expression
  #
  def query_Object(o)
    raise "Not a valid expression in a collection query: "+o.class.name
  end

  # Puppet AST only allows == and !=, and left expr is restricted, but right value is an expression
  #
  def query_ComparisonExpression(o)
    if [:'==', :'!='].include? o.operator
      ast o, AST::CollExpr, :test1 => query(o.left_expr), :oper => o.operator.to_s, :test2 => transform(o.right_expr)
    else
      raise "Not a valid comparison operator in a collection query: " + o.operator.to_s
    end
  end

  def query_AndExpression(o)
    ast o, AST::CollExpr, :test1 => query(o.left_expr), :oper => 'and', :test2 => query(o.right_expr)
  end

  def query_OrExpression(o)
    ast o, AST::CollExpr, :test1 => query(o.left_expr), :oper => 'or', :test2 => query(o.right_expr)
  end

  def query_ParenthesizedExpression(o)
    result = query(o.expr) # produces CollExpr
    result.parens = true
    result
  end

  def query_VariableExpression(o)
    transform(o)
  end

  def query_QualifiedName(o)
    transform(o)
  end

  def query_LiteralNumber(o)
    transform(o) # number to string in correct radix
  end

  def query_LiteralString(o)
    transform(o)
  end

  def query_LiteralBoolean(o)
    transform(o)
  end

  def transform_QualifiedName(o)
    ast o, AST::Name, :value => o.value
  end

  def transform_QualifiedReference(o)
    ast o, AST::Type, :value => o.value
  end

  def transform_ComparisonExpression(o)
    ast o, AST::ComparisonOperator, :operator => o.operator.to_s, :lval => transform(o.left_expr), :rval => transform(o.right_expr)
  end

  def transform_AndExpression(o)
    ast o, AST::BooleanOperator, :operator => 'and', :lval => transform(o.left_expr), :rval => transform(o.right_expr)
  end

  def transform_OrExpression(o)
    ast o, AST::BooleanOperator, :operator => 'or', :lval => transform(o.left_expr), :rval => transform(o.right_expr)
  end

  def transform_InExpression(o)
    ast o, AST::InOperator, :lval => transform(o.left_expr), :rval => transform(o.right_expr)
  end

  # Assignment in AST 3.1 is to variable or hasharray accesses !!! See Bug #16116
  def transform_AssignmentExpression(o)
    args = {:value => transform(o.right_expr) }
    case o.operator
    when :'+='
      args[:append] = true
    when :'='
    else
      raise "The operator #{o.operator} is not supported by Puppet 3."
    end

    args[:name] = case o.left_expr
    when Model::VariableExpression
      ast o, AST::Name, {:value => o.left_expr.expr.value }
    when Model::AccessExpression
      transform(o.left_expr)
    else
      raise "LHS is not an expression that can be assigned to"
    end
    ast o, AST::VarDef, args
  end

  # Produces (name => expr) or (name +> expr)
  def transform_AttributeOperation(o)
    args = { :value => transform(o.value_expr) }
    args[:add] = true if o.operator == :'+>'
    args[:param] = o.attribute_name
    ast o, AST::ResourceParam, args
  end

  def transform_LiteralList(o)
    # Uses default transform of Ruby Array to ASTArray
    transform(o.values)
  end

  # Literal hash has strange behavior in Puppet 3.1. See Bug #19426, and this implementation is bug
  # compatible
  def transform_LiteralHash(o)
    if o.entries.size == 0
      ast o, AST::ASTHash, {:value=> {}}
    else
      value = {}
      o.entries.each {|x| value.merge! transform(x) }
      ast o, AST::ASTHash, {:value=> value}
    end
  end

  # Transforms entry into a hash (they are later merged with strange effects: Bug #19426).
  # Puppet 3.x only allows:
  # * NAME
  # * quotedtext
  # As keys (quoted text can be an interpolated string which is compared as a key in a less than satisfactory way).
  #
  def transform_KeyedEntry(o)
    value = transform(o.value)
    key = case o.key
    when Model::QualifiedName
      o.key.value
    when Model::LiteralString
      transform o.key
    when Model::LiteralNumber
      transform o.key
    when Model::ConcatenatedString
      transform o.key
    else
      raise "Illegal hash key expression of type (#{o.key.class})"
    end
    {key => value}
  end

  def transform_MatchExpression(o)
    ast o, AST::MatchOperator, :operator => o.operator.to_s, :lval => transform(o.left_expr), :rval => transform(o.right_expr)
  end

  def transform_LiteralString(o)
    ast o, AST::String, :value => o.value
  end

  def transform_LambdaExpression(o)
    astargs = { :parameters => o.parameters.collect {|p| transform(p) } }
    astargs.merge!({ :children => transform(o.body) }) if o.body         # do not want children if it is nil/nop
    ast o, AST::Lambda, astargs
  end

  def transform_LiteralDefault(o)
    ast o, AST::Default, :value => :default
  end

  def transform_LiteralUndef(o)
    ast o, AST::Undef, :value => :undef
  end

  def transform_LiteralRegularExpression(o)
    ast o, AST::Regex, :value => o.value
  end

  def transform_Nop(o)
    ast o, AST::Nop
  end

  # In the 3.1. grammar this is a hash that is merged with other elements to form a method call
  # Also in 3.1. grammar there are restrictions on the LHS (that are only there for grammar issues).
  #
  def transform_NamedAccessExpression(o)
    receiver = transform(o.left_expr)
    name = o.right_expr
    raise "Unacceptable function/method name" unless name.is_a? Model::QualifiedName
    {:receiver => receiver, :name => name.value}
  end

  def transform_NilClass(o)
    ast o, AST::Nop, {}
  end

  def transform_NotExpression(o)
    ast o, AST::Not, :value => transform(o.expr)
  end

  def transform_VariableExpression(o)
    # assumes the expression is a QualifiedName
    ast o, AST::Variable, :value => o.expr.value
  end

  # In Puppet 3.1, the ConcatenatedString is responsible for the evaluation and stringification of
  # expression segments. Expressions and Strings are kept in an array.
  def transform_TextExpression(o)
    transform(o.expr)
  end

  def transform_UnaryMinusExpression(o)
    ast o, AST::Minus, :value => transform(o.expr)
  end

  # Puppet 3.1 representation of a BlockExpression is an AST::Array - this makes it impossible to differentiate
  # between a LiteralArray and a Sequence. (Should it return the collected array, or the last expression?)
  # (A BlockExpression has now been introduced in the AST to solve this).
  #
  def transform_BlockExpression(o)
    children = []
    # remove nops resulting from import
    o.statements.each {|s| r = transform(s); children << r unless is_nop?(r) }
    ast o, AST::BlockExpression, :children => children  # o.statements.collect {|s| transform(s) }
  end

  # Interpolated strings are kept in an array of AST (string or other expression).
  def transform_ConcatenatedString(o)
    ast o, AST::Concat, :value => o.segments.collect {|x| transform(x)}
  end

  def transform_HostClassDefinition(o)
    parameters = o.parameters.collect {|p| transform(p) }
    args = {
      :arguments => parameters,
      :parent => o.parent_class,
    }
    args[:code] = transform(o.body) unless is_nop?(o.body)
    Puppet::Parser::AST::Hostclass.new(o.name, merge_location(args, o))
  end

  def transform_HeredocExpression(o)
    # TODO_HEREDOC Not supported in 3x
    args = {:syntax=> o.syntax(), :expr => transform(o.text_expr()) }
    Puppet::Parser::AST::Heredoc.new(merge_location(args, o))
  end

  def transform_NodeDefinition(o)
    # o.host_matches are expressions, and 3.1 AST requires special object AST::HostName
    # where a HostName is one of NAME, STRING, DEFAULT or Regexp - all of these are strings except regexp
    #
    args = {
      :code => transform(o.body)
    }
    args[:parent] = hostname(o.parent) unless is_nop?(o.parent)
    if(args[:parent].is_a?(Array))
      raise "Illegal expression - unacceptable as a node parent"
    end
    Puppet::Parser::AST::Node.new(hostname(o.host_matches), merge_location(args, o))
  end

  # Transforms Array of host matching expressions into a (Ruby) array of AST::HostName
  def hostname_Array(o)
    o.collect {|x| ast x, AST::HostName, :value => hostname(x) }
  end

  def hostname_LiteralValue(o)
    return o.value
  end

  def hostname_QualifiedName(o)
    return o.value
  end

  def hostname_LiteralNumber(o)
    transform(o) # Number to string with correct radix
  end

  def hostname_LiteralDefault(o)
    return 'default'
  end

  def hostname_LiteralRegularExpression(o)
    ast o, AST::Regex, :value => o.value
  end

  def hostname_Object(o)
    raise "Illegal expression - unacceptable as a node name"
  end

  def transform_RelationshipExpression(o)
    Puppet::Parser::AST::Relationship.new(transform(o.left_expr), transform(o.right_expr), o.operator.to_s, merge_location({}, o))
  end

  def transform_RenderStringExpression(o)
    # TODO_EPP Not supported in 3x
    ast o, AST::RenderString, :value => o.value
  end

  def transform_RenderExpression(o)
    # TODO_EPP Not supported in 3x
    ast o, AST::RenderExpression, :value => transform(o.expr)
  end

  def transform_ResourceTypeDefinition(o)
    parameters = o.parameters.collect {|p| transform(p) }
    args = { :arguments => parameters }
    args[:code] = transform(o.body) unless is_nop?(o.body)

    Puppet::Parser::AST::Definition.new(o.name, merge_location(args, o))
  end

  # Transformation of ResourceOverrideExpression is slightly more involved than a straight forward
  # transformation.
  # A ResourceOverrideExppression has "resources" which should be an AccessExpression
  # on the form QualifiedName[expressions], or QualifiedReference[expressions] to be valid.
  # It also has a set of attribute operations.
  #
  # The AST equivalence is an AST::ResourceOverride with a ResourceReference as its LHS, and
  # a set of Parameters.
  # ResourceReference has type as a string, and the expressions representing
  # the "titles" to be an ASTArray.
  #
  def transform_ResourceOverrideExpression(o)
    raise "Unsupported transformation - use the new evaluator"
  end

  # Parameter is a parameter in a definition of some kind.
  # It is transformed to an array on the form `[name]´, or `[name, value]´.
  def transform_Parameter(o)
    if o.value
      [o.name, transform(o.value)]
    else
      [o.name]
    end
  end

  # For non query expressions, parentheses can be dropped in the resulting AST.
  def transform_ParenthesizedExpression(o)
    transform(o.expr)
  end

  def transform_Program(o)
    transform(o.body)
  end

  def transform_IfExpression(o)
    args = { :test => transform(o.test), :statements => transform(o.then_expr) }
    args[:else] = transform(o.else_expr) # Tests say Nop should be there (unless is_nop? o.else_expr), probably not needed
    ast o, AST::IfStatement, args
  end

  # Unless is not an AST object, instead an AST::IfStatement is used with an AST::Not around the test
  #
  def transform_UnlessExpression(o)
    args = { :test => ast(o, AST::Not, :value => transform(o.test)),
      :statements => transform(o.then_expr) }
    # AST 3.1 does not allow else on unless in the grammar, but it is ok since unless is encoded as an if !x
    args.merge!({:else => transform(o.else_expr)}) unless is_nop?(o.else_expr)
    ast o, AST::IfStatement, args
  end

  # Puppet 3.1 AST only supports calling a function by name (it is not possible to produce a function
  # that is then called).
  # rval_required (for an expression)
  # functor_expr (lhs - the "name" expression)
  # arguments - list of arguments
  #
  def transform_CallNamedFunctionExpression(o)
    name = o.functor_expr
    raise "Unacceptable expression for name of function" unless name.is_a? Model::QualifiedName
    args = {
      :name => name.value,
      :arguments => transform(o.arguments),
      :ftype => o.rval_required ? :rvalue : :statement
    }
    args[:pblock] = transform(o.lambda) if o.lambda
    ast o, AST::Function, args
  end

  # Transformation of CallMethodExpression handles a NamedAccessExpression functor and
  # turns this into a 3.1 AST::MethodCall.
  #
  def transform_CallMethodExpression(o)
    name = o.functor_expr
    raise "Unacceptable expression for name of function" unless name.is_a? Model::NamedAccessExpression
    # transform of NamedAccess produces a hash, add arguments to it
    astargs = transform(name).merge(:arguments => transform(o.arguments))
    astargs.merge!(:lambda => transform(o.lambda)) if o.lambda # do not want a Nop as the lambda
    ast o, AST::MethodCall, astargs

  end

  def transform_CaseExpression(o)
    # Expects expression, AST::ASTArray of AST
    ast o, AST::CaseStatement, :test => transform(o.test), :options => transform(o.options)
  end

  def transform_CaseOption(o)
    ast o, AST::CaseOpt, :value => transform(o.values), :statements => transform(o.then_expr)
  end

  def transform_ResourceBody(o)
    raise "Unsupported transformation - use the new evaluator"
  end

  def transform_ResourceDefaultsExpression(o)
    raise "Unsupported transformation - use the new evaluator"
  end

  # Transformation of ResourceExpression requires calling a method on the resulting
  # AST::Resource if it is virtual or exported
  #
  def transform_ResourceExpression(o)
    raise "Unsupported transformation - use the new evaluator"
  end

  # Transformation of SelectorExpression is limited to certain types of expressions.
  # This is probably due to constraints in the old grammar rather than any real concerns.
  def transform_SelectorExpression(o)
    case o.left_expr
    when Model::CallNamedFunctionExpression
    when Model::AccessExpression
    when Model::VariableExpression
    when Model::ConcatenatedString
    else
      raise "Unacceptable select expression" unless o.left_expr.kind_of? Model::Literal
    end
    ast o, AST::Selector, :param => transform(o.left_expr), :values => transform(o.selectors)
  end

  def transform_SelectorEntry(o)
    ast o, AST::ResourceParam, :param => transform(o.matching_expr), :value => transform(o.value_expr)
  end

  def transform_Object(o)
    raise "Unacceptable transform - found an Object without a rule: #{o.class}"
  end

  # Nil, nop
  # Bee bopp a luh-lah, a bop bop boom.
  #
  def is_nop?(o)
    o.nil? || o.is_a?(Model::Nop)
  end
end
