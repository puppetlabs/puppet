# A Validator validates a model.
#
# Validation is performed on each model element in isolation. Each method should validate the model element's state
# but not validate its referenced/contained elements except to check their validity in their respective role.
# The intent is to drive the validation with a tree iterator that visits all elements in a model.
#
#
# TODO: Add validation of multiplicities - this is a general validation that can be checked for all
#       Model objects via their metamodel. (I.e an extra call to multiplicity check in polymorph check).
#       This is however mostly valuable when validating model to model transformations, and is therefore T.B.D
#
class Puppet::Pops::Validation::Checker3_1
  Issues = Puppet::Pops::Issues
  Model = Puppet::Pops::Model

  attr_reader :acceptor
  # Initializes the validator with a diagnostics producer. This object must respond to
  # `:will_accept?` and `:accept`.
  #
  def initialize(diagnostics_producer)
    @@check_visitor       ||= Puppet::Pops::Visitor.new(nil, "check", 0, 0)
    @@rvalue_visitor      ||= Puppet::Pops::Visitor.new(nil, "rvalue", 0, 0)
    @@hostname_visitor    ||= Puppet::Pops::Visitor.new(nil, "hostname", 1, 2)
    @@assignment_visitor  ||= Puppet::Pops::Visitor.new(nil, "assign", 0, 1)
    @@query_visitor       ||= Puppet::Pops::Visitor.new(nil, "query", 0, 0)
    @@top_visitor         ||= Puppet::Pops::Visitor.new(nil, "top", 1, 1)
    @@relation_visitor    ||= Puppet::Pops::Visitor.new(nil, "relation", 1, 1)

    @acceptor = diagnostics_producer
  end

  # Validates the entire model by visiting each model element and calling `check`.
  # The result is collected (or acted on immediately) by the configured diagnostic provider/acceptor
  # given when creating this Checker.
  #
  def validate(model)
    # tree iterate the model, and call check for each element
    check(model)
    model.eAllContents.each {|m| check(m) }
  end

  # Performs regular validity check
  def check(o)
    @@check_visitor.visit_this(self, o)
  end

  # Performs check if this is a vaid hostname expression
  # @param single_feature_name [String, nil] the name of a single valued hostname feature of the value's container. e.g. 'parent'
  def hostname(o, semantic, single_feature_name = nil)
    @@hostname_visitor.visit_this(self, o, semantic, single_feature_name)
  end

  # Performs check if this is valid as a query
  def query(o)
    @@query_visitor.visit_this(self, o)
  end

  # Performs check if this is valid as a relationship side
  def relation(o, container)
    @@relation_visitor.visit_this(self, o, container)
  end

  # Performs check if this is valid as a rvalue
  def rvalue(o)
    @@rvalue_visitor.visit_this(self, o)
  end

  # Performs check if this is valid as a container of a definition (class, define, node)
  def top(o, definition)
    @@top_visitor.visit_this(self, o, definition)
  end

  # Checks the LHS of an assignment (is it assignable?).
  # If args[0] is true, assignment via index is checked.
  #
  def assign(o, *args)
    @@assignment_visitor.visit_this(self, o, *args)
  end

  #---ASSIGNMENT CHECKS

  def assign_VariableExpression(o, *args)
    varname_string = varname_to_s(o.expr)
    if varname_string =~ /^[0-9]+$/
      acceptor.accept(Issues::ILLEGAL_NUMERIC_ASSIGNMENT, o, :varname => varname_string)
    end
    # Can not assign to something in another namespace (i.e. a '::' in the name is not legal)
    if acceptor.will_accept? Issues::CROSS_SCOPE_ASSIGNMENT
      if varname_string =~ /::/
        acceptor.accept(Issues::CROSS_SCOPE_ASSIGNMENT, o, :name => varname_string)
      end
    end
    # TODO: Could scan for reassignment of the same variable if done earlier in the same container
    #       Or if assigning to a parameter (more work).
    # TODO: Investigate if there are invalid cases for += assignment
  end

  def assign_AccessExpression(o, *args)
    # Are indexed assignments allowed at all ? $x[x] = '...'
    if acceptor.will_accept? Issues::ILLEGAL_INDEXED_ASSIGNMENT
      acceptor.accept(Issues::ILLEGAL_INDEXED_ASSIGNMENT, o)
    else
      # Then the left expression must be assignable-via-index
      assign(o.left_expr, true)
    end
  end

  def assign_Object(o, *args)
    # Can not assign to anything else (differentiate if this is via index or not)
    # i.e. 10 = 'hello' vs. 10['x'] = 'hello' (the root is reported as being in error in both cases)
    #
    acceptor.accept(args[0] ? Issues::ILLEGAL_ASSIGNMENT_VIA_INDEX : Issues::ILLEGAL_ASSIGNMENT, o)
  end

  #---CHECKS

  def check_Object(o)
  end

  def check_Factory(o)
    check(o.current)
  end

  def check_AccessExpression(o)
    # Check multiplicity of keys
    case o.left_expr
    when Model::QualifiedName
      # allows many keys, but the name should really be a QualifiedReference
      acceptor.accept(Issues::DEPRECATED_NAME_AS_TYPE, o, :name => o.left_expr.value)
    when Model::QualifiedReference
      # ok, allows many - this is a resource reference

    else
      # i.e. for any other expression that may produce an array or hash
      if o.keys.size > 1
        acceptor.accept(Issues::UNSUPPORTED_RANGE, o, :count => o.keys.size)
      end
      if o.keys.size < 1
        acceptor.accept(Issues::MISSING_INDEX, o)
      end
    end
  end

  def check_AssignmentExpression(o)
    assign(o.left_expr)
    rvalue(o.right_expr)
  end

  # Checks that operation with :+> is contained in a ResourceOverride or Collector.
  #
  # Parent of an AttributeOperation can be one of:
  # * CollectExpression
  # * ResourceOverride
  # * ResourceBody (ILLEGAL this is a regular resource expression)
  # * ResourceDefaults (ILLEGAL)
  #
  def check_AttributeOperation(o)
    if o.operator == :'+>'
      # Append operator use is constrained
      parent = o.eContainer
      unless parent.is_a?(Model::CollectExpression) || parent.is_a?(Model::ResourceOverrideExpression)
        acceptor.accept(Issues::ILLEGAL_ATTRIBUTE_APPEND, o, {:name=>o.attribute_name, :parent=>parent})
      end
    end
    rvalue(o.value_expr)
  end

  def check_BinaryExpression(o)
    rvalue(o.left_expr)
    rvalue(o.right_expr)
  end

  def check_CallNamedFunctionExpression(o)
    unless o.functor_expr.is_a? Model::QualifiedName
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.functor_expr, :feature => 'function name', :container => o)
    end
  end

  def check_MethodCallExpression(o)
    unless o.functor_expr.is_a? Model::QualifiedName
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.functor_expr, :feature => 'function name', :container => o)
    end
  end

  def check_CaseExpression(o)
    # There should only be one LiteralDefault case option value
    # TODO: Implement this check
  end

  def check_CollectExpression(o)
    unless o.type_expr.is_a? Model::QualifiedReference
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.type_expr, :feature=> 'type name', :container => o)
    end

    # If a collect expression tries to collect exported resources and storeconfigs is not on
    # then it will not work... This was checked in the parser previously. This is a runtime checking
    # thing as opposed to a language thing.
    if acceptor.will_accept?(Issues::RT_NO_STORECONFIGS) && o.query.is_a?(Model::ExportedQuery)
      acceptor.accept(Issues::RT_NO_STORECONFIGS, o)
    end
  end

  # Only used for function names, grammar should not be able to produce something faulty, but
  # check anyway if model is created programatically (it will fail in transformation to AST for sure).
  def check_NamedAccessExpression(o)
    name = o.right_expr
    unless name.is_a? Model::QualifiedName
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, name, :feature=> 'function name', :container => o.eContainer)
    end
  end

  # for 'class' and 'define'
  def check_NamedDefinition(o)
    top(o.eContainer, o)
    if (acceptor.will_accept? Issues::NAME_WITH_HYPHEN) && o.name.include?('-')
      acceptor.accept(Issues::NAME_WITH_HYPHEN, o, {:name => o.name})
    end
  end

  def check_ImportExpression(o)
    o.files.each do |f|
      unless f.is_a? Model::LiteralString
        acceptor.accept(Issues::ILLEGAL_EXPRESSION, f, :feature => 'file name', :container => o)
      end
    end
  end

  def check_InstanceReference(o)
    # TODO: Original warning is :
    #       Puppet.warning addcontext("Deprecation notice:  Resource references should now be capitalized")
    #       This model element is not used in the egrammar.
    #       Either implement checks or deprecate the use of InstanceReference (the same is acheived by
    #       transformation of AccessExpression when used where an Instance/Resource reference is allowed.
    #
  end

  # Restrictions on hash key are because of the strange key comparisons/and merge rules in the AST evaluation
  # (Even the allowed ones are handled in a strange way).
  #
  def transform_KeyedEntry(o)
    case o.key
    when Model::QualifiedName
    when Model::LiteralString
    when Model::LiteralNumber
    when Model::ConcatenatedString
    else
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.key, :feature => 'hash key', :container => o.eContainer)
    end
  end

  # A Lambda is a Definition, but it may appear in other scopes that top scope (Which check_Definition asserts).
  #
  def check_LambdaExpression(o)
  end

  def check_NodeDefinition(o)
    # Check that hostnames are valid hostnames (or regular expressons)
    hostname(o.host_matches, o)
    hostname(o.parent, o, 'parent') unless o.parent.nil?
    top(o.eContainer, o)
  end

  # Asserts that value is a valid QualifiedName. No additional checking is made, objects that use
  # a QualifiedName as a name should check the validity - this since a QualifiedName is used as a BARE WORD
  # and then additional chars may be valid (like a hyphen).
  #
  def check_QualifiedName(o)
    # Is this a valid qualified name?
    if o.value !~ Puppet::Pops::Patterns::NAME
      acceptor.accept(Issues::ILLEGAL_NAME, o, {:name=>o.value})
    end
  end

  # Checks that the value is a valid UpperCaseWord (a CLASSREF), and optionally if it contains a hypen.
  # DOH: QualifiedReferences are created with LOWER CASE NAMES at parse time
  def check_QualifiedReference(o)
    # Is this a valid qualified name?
    if o.value !~ Puppet::Pops::Patterns::CLASSREF
      acceptor.accept(Issues::ILLEGAL_CLASSREF, o, {:name=>o.value})
    elsif (acceptor.will_accept? Issues::NAME_WITH_HYPHEN) && o.value.include?('-')
      acceptor.accept(Issues::NAME_WITH_HYPHEN, o, {:name => o.value})
    end
  end

  def check_QueryExpression(o)
    query(o.expr) if o.expr  # is optional
  end

  def relation_Object(o, rel_expr)
    acceptor.accept(Issues::ILLEGAL_EXPRESSION, o, {:feature => o.eContainingFeature, :container => rel_expr})
  end

  def relation_AccessExpression(o, rel_expr); end

  def relation_CollectExpression(o, rel_expr); end

  def relation_VariableExpression(o, rel_expr); end

  def relation_LiteralString(o, rel_expr); end

  def relation_ConcatenatedStringExpression(o, rel_expr); end

  def relation_SelectorExpression(o, rel_expr); end

  def relation_CaseExpression(o, rel_expr); end

  def relation_ResourceExpression(o, rel_expr); end

  def relation_RelationshipExpression(o, rel_expr); end

  def check_Parameter(o)
    if o.name =~ /^[0-9]+$/
      acceptor.accept(Issues::ILLEGAL_NUMERIC_PARAMETER, o, :name => o.name)
    end
  end

  #relationship_side: resource
  #  | resourceref
  #  | collection
  #  | variable
  #  | quotedtext
  #  | selector
  #  | casestatement
  #  | hasharrayaccesses

  def check_RelationshipExpression(o)
    relation(o.left_expr, o)
    relation(o.right_expr, o)
  end

  def check_ResourceExpression(o)
    # A resource expression must have a lower case NAME as its type e.g. 'file { ... }'
    unless o.type_name.is_a? Model::QualifiedName
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.type_name, :feature => 'resource type', :container => o)
    end

    # This is a runtime check - the model is valid, but will have runtime issues when evaluated
    # and storeconfigs is not set.
    if acceptor.will_accept?(Issues::RT_NO_STORECONFIGS) && o.exported
      acceptor.accept(Issues::RT_NO_STORECONFIGS_EXPORT, o)
    end
  end

  def check_ResourceDefaultsExpression(o)
    if o.form && o.form != :regular
      acceptor.accept(Issues::NOT_VIRTUALIZEABLE, o)
    end
  end

  # Transformation of SelectorExpression is limited to certain types of expressions.
  # This is probably due to constraints in the old grammar rather than any real concerns.
  def select_SelectorExpression(o)
    case o.left_expr
    when Model::CallNamedFunctionExpression
    when Model::AccessExpression
    when Model::VariableExpression
    when Model::ConcatenatedString
    else
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.left_expr, :feature => 'left operand', :container => o)
    end
  end

  def check_UnaryExpression(o)
    rvalue(o.expr)
  end

  def check_UnlessExpression(o)
    # TODO: Unless may not have an elsif
    # TODO: 3.x unless may not have an else
  end

  def check_VariableExpression(o)
    # The expression must be a qualified name
    if !o.expr.is_a? Model::QualifiedName
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o, :feature => 'name', :container => o)
    else
      # Note, that if it later becomes illegal with hyphen in any name, this special check
      # can be skipped in favor of the check in QualifiedName, which is now not done if contained in
      # a VariableExpression
      name = o.expr.value
      if (acceptor.will_accept? Issues::VAR_WITH_HYPHEN) && name.include?('-')
        acceptor.accept(Issues::VAR_WITH_HYPHEN, o, {:name => name})
      end
    end
  end

  #--- HOSTNAME CHECKS

  # Transforms Array of host matching expressions into a (Ruby) array of AST::HostName
  def hostname_Array(o, semantic, single_feature_name)
    if single_feature_name
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o, {:feature=>single_feature_name, :container=>semantic})
    end
    o.each {|x| hostname(x, semantic, false) }
  end

  def hostname_String(o, semantic, single_feature_name)
    # The 3.x checker only checks for illegal characters - if matching /[^-\w.]/ the name is invalid,
    # but this allows pathological names like "a..b......c", "----"
    # TODO: Investigate if more illegal hostnames should be flagged.
    #
    if o =~ Puppet::Pops::Patterns::ILLEGAL_HOSTNAME_CHARS
      acceptor.accept(Issues::ILLEGAL_HOSTNAME_CHARS, semantic, :hostname => o)
    end
  end

  def hostname_LiteralValue(o, semantic, single_feature_name)
    hostname_String(o.value.to_s, o, single_feature_name)
  end

  def hostname_ConcatenatedString(o, semantic, single_feature_name)
    # Puppet 3.1. only accepts a concatenated string without interpolated expressions
    if the_expr = o.segments.index {|s| s.is_a?(Model::TextExpression) }
      acceptor.accept(Issues::ILLEGAL_HOSTNAME_INTERPOLATION, o.segments[the_expr].expr)
    elsif o.segments.size() != 1
      # corner case, bad model, concatenation of several plain strings
      acceptor.accept(Issues::ILLEGAL_HOSTNAME_INTERPOLATION, o)
    else
      # corner case, may be ok, but lexer may have replaced with plain string, this is
      # here if it does not
      hostname_String(o.segments[0], o.segments[0], false)
    end
  end

  def hostname_QualifiedName(o, semantic, single_feature_name)
    hostname_String(o.value.to_s, o, single_feature_name)
  end

  def hostname_QualifiedReference(o, semantic, single_feature_name)
    hostname_String(o.value.to_s, o, single_feature_name)
  end

  def hostname_LiteralNumber(o, semantic, single_feature_name)
    # always ok
  end

  def hostname_LiteralDefault(o, semantic, single_feature_name)
    # always ok
  end

  def hostname_LiteralRegularExpression(o, semantic, single_feature_name)
    # always ok
  end

  def hostname_Object(o, semantic, single_feature_name)
    acceptor.accept(Issues::ILLEGAL_EXPRESSION, o, {:feature=> single_feature_name || 'hostname', :container=>semantic})
  end

  #---QUERY CHECKS

  # Anything not explicitly allowed is flagged as error.
  def query_Object(o)
    acceptor.accept(Issues::ILLEGAL_QUERY_EXPRESSION, o)
  end

  # Puppet AST only allows == and !=
  #
  def query_ComparisonExpression(o)
    acceptor.accept(Issues::ILLEGAL_QUERY_EXPRESSION, o) unless [:'==', :'!='].include? o.operator
  end

  # Allows AND, OR, and checks if left/right are allowed in query.
  def query_BooleanExpression(o)
    query o.left_expr
    query o.right_expr
  end

  def query_ParenthesizedExpression(o)
    query(o.expr)
  end

  def query_VariableExpression(o); end

  def query_QualifiedName(o); end

  def query_LiteralNumber(o); end

  def query_LiteralString(o); end

  def query_LiteralBoolean(o); end

  #---RVALUE CHECKS

  # By default, all expressions are reported as being rvalues
  # Implement specific rvalue checks for those that are not.
  #
  def rvalue_Expression(o); end

  def rvalue_ImportExpression(o)          ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_BlockExpression(o)           ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_CaseExpression(o)            ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_IfExpression(o)              ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_UnlessExpression(o)          ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_ResourceExpression(o)        ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_ResourceDefaultsExpression(o); acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_ResourceOverrideExpression(o); acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_CollectExpression(o)         ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_Definition(o)                ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_NodeDefinition(o)            ; acceptor.accept(Issues::NOT_RVALUE, o) ; end

  def rvalue_UnaryExpression(o)           ; rvalue o.expr                 ; end

  #---TOP CHECK

  def top_NilClass(o, definition)
    # ok, reached the top, no more parents
  end

  def top_Object(o, definition)
    # fail, reached a container that is not top level
    acceptor.accept(Issues::NOT_TOP_LEVEL, definition)
  end

  def top_BlockExpression(o, definition)
    # ok, if this is a block representing the body of a class, or is top level
    top o.eContainer, definition
  end

  def top_HostClassDefinition(o, definition)
    # ok, stop scanning parents
  end

  # A LambdaExpression is a BlockExpression, and this method is needed to prevent the polymorph method for BlockExpression
  # to accept a lambda.
  # A lambda can not iteratively create classes, nodes or defines as the lambda does not have a closure.
  #
  def top_LambdaExpression(o, definition)
    # fail, stop scanning parents
    acceptor.accept(Issues::NOT_TOP_LEVEL, definition)
  end

  #--- NON POLYMORPH, NON CHECKING CODE

  # Produces string part of something named, or nil if not a QualifiedName or QualifiedReference
  #
  def varname_to_s(o)
    case o
    when Model::QualifiedName
      o.value
    when Model::QualifiedReference
      o.value
    else
      nil
    end
  end
end
