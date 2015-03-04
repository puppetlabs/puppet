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
class Puppet::Pops::Validation::Checker4_0
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
    @@relation_visitor    ||= Puppet::Pops::Visitor.new(nil, "relation", 0, 0)
    @@idem_visitor        ||= Puppet::Pops::Visitor.new(self, "idem", 0, 0)

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
    @@check_visitor.visit_this_0(self, o)
  end

  # Performs check if this is a vaid hostname expression
  # @param single_feature_name [String, nil] the name of a single valued hostname feature of the value's container. e.g. 'parent'
  def hostname(o, semantic, single_feature_name = nil)
    @@hostname_visitor.visit_this_2(self, o, semantic, single_feature_name)
  end

  # Performs check if this is valid as a query
  def query(o)
    @@query_visitor.visit_this_0(self, o)
  end

  # Performs check if this is valid as a relationship side
  def relation(o)
    @@relation_visitor.visit_this_0(self, o)
  end

  # Performs check if this is valid as a rvalue
  def rvalue(o)
    @@rvalue_visitor.visit_this_0(self, o)
  end

  # Performs check if this is valid as a container of a definition (class, define, node)
  def top(o, definition)
    @@top_visitor.visit_this_1(self, o, definition)
  end

  # Checks the LHS of an assignment (is it assignable?).
  # If args[0] is true, assignment via index is checked.
  #
  def assign(o, via_index = false)
    @@assignment_visitor.visit_this_1(self, o, via_index)
  end

  # Checks if the expression has side effect ('idem' is latin for 'the same', here meaning that the evaluation state
  # is known to be unchanged after the expression has been evaluated). The result is not 100% authoritative for
  # negative answers since analysis of function behavior is not possible.
  # @return [Boolean] true if expression is known to have no effect on evaluation state
  #
  def idem(o)
    @@idem_visitor.visit_this_0(self, o)
  end

  # Returns the last expression in a block, or the expression, if that expression is idem
  def ends_with_idem(o)
    if o.is_a?(Puppet::Pops::Model::BlockExpression)
      last = o.statements[-1]
      idem(last) ? last : nil
    else
      idem(o) ? o : nil
    end
  end

  #---ASSIGNMENT CHECKS

  def assign_VariableExpression(o, via_index)
    varname_string = varname_to_s(o.expr)
    if varname_string =~ Puppet::Pops::Patterns::NUMERIC_VAR_NAME
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

  def assign_AccessExpression(o, via_index)
    # Are indexed assignments allowed at all ? $x[x] = '...'
    if acceptor.will_accept? Issues::ILLEGAL_INDEXED_ASSIGNMENT
      acceptor.accept(Issues::ILLEGAL_INDEXED_ASSIGNMENT, o)
    else
      # Then the left expression must be assignable-via-index
      assign(o.left_expr, true)
    end
  end

  def assign_Object(o, via_index)
    # Can not assign to anything else (differentiate if this is via index or not)
    # i.e. 10 = 'hello' vs. 10['x'] = 'hello' (the root is reported as being in error in both cases)
    #
    acceptor.accept(via_index ? Issues::ILLEGAL_ASSIGNMENT_VIA_INDEX : Issues::ILLEGAL_ASSIGNMENT, o)
  end

  #---CHECKS

  def check_Object(o)
  end

  def check_Factory(o)
    check(o.current)
  end

  def check_AccessExpression(o)
    # Only min range is checked, all other checks are RT checks as they depend on the resulting type
    # of the LHS.
    if o.keys.size < 1
      acceptor.accept(Issues::MISSING_INDEX, o)
    end
  end

  def check_AssignmentExpression(o)
    case o.operator
    when :'='
      assign(o.left_expr)
      rvalue(o.right_expr)
    when :'+=', :'-='
      acceptor.accept(Issues::APPENDS_DELETES_NO_LONGER_SUPPORTED, o, {:operator => o.operator})
    else
      acceptor.accept(Issues::UNSUPPORTED_OPERATOR, o, {:operator => o.operator})
    end
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

  def check_AttributesOperation(o)
    # Append operator use is constrained
    parent = o.eContainer
    parent = parent.eContainer unless parent.nil?
    unless parent.is_a?(Model::ResourceExpression)
      acceptor.accept(Issues::UNSUPPORTED_OPERATOR_IN_CONTEXT, o, :operator=>'* =>')
    end

    rvalue(o.expr)
  end

  def check_BinaryExpression(o)
    rvalue(o.left_expr)
    rvalue(o.right_expr)
  end

  def check_BlockExpression(o)
    o.statements[0..-2].each do |statement|
      if idem(statement)
        acceptor.accept(Issues::IDEM_EXPRESSION_NOT_LAST, statement)
        break # only flag the first
      end
    end
  end

  def check_CallNamedFunctionExpression(o)
    case o.functor_expr
    when Puppet::Pops::Model::QualifiedName
      # ok
      nil
    when Puppet::Pops::Model::RenderStringExpression
      # helpful to point out this easy to make Epp error
      acceptor.accept(Issues::ILLEGAL_EPP_PARAMETERS, o)
    else
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function name', :container => o})
    end
  end

  def check_EppExpression(o)
    if o.eContainer.is_a?(Puppet::Pops::Model::LambdaExpression)
      internal_check_no_capture(o.eContainer, o)
    end
  end

  def check_MethodCallExpression(o)
    unless o.functor_expr.is_a? Model::QualifiedName
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.functor_expr, :feature => 'function name', :container => o)
    end
  end

  def check_CaseExpression(o)
    rvalue(o.test)
    # There should only be one LiteralDefault case option value
    # TODO: Implement this check
  end

  def check_CaseOption(o)
    o.values.each { |v| rvalue(v) }
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

  RESERVED_TYPE_NAMES = {
    'type' => true,
    'any' => true,
    'unit' => true,
    'scalar' => true,
    'boolean' => true,
    'numeric' => true,
    'integer' => true,
    'float' => true,
    'collection' => true,
    'array' => true,
    'hash' => true,
    'tuple' => true,
    'struct' => true,
    'variant' => true,
    'optional' => true,
    'enum' => true,
    'regexp' => true,
    'pattern' => true,
    'runtime' => true,
  }

  # for 'class', 'define', and function
  def check_NamedDefinition(o)
    top(o.eContainer, o)
    if o.name !~ Puppet::Pops::Patterns::CLASSREF
      acceptor.accept(Issues::ILLEGAL_DEFINITION_NAME, o, {:name=>o.name})
    end

    if RESERVED_TYPE_NAMES[o.name()]
      acceptor.accept(Issues::RESERVED_TYPE_NAME, o, {:name => o.name})
    end

    if violator = ends_with_idem(o.body)
      acceptor.accept(Issues::IDEM_NOT_ALLOWED_LAST, violator, {:container => o})
    end
  end

  def check_HostClassDefinition(o)
    check_NamedDefinition(o)
    internal_check_no_capture(o)
    internal_check_reserved_params(o)
  end

  def check_ResourceTypeDefinition(o)
    check_NamedDefinition(o)
    internal_check_no_capture(o)
    internal_check_reserved_params(o)
  end

  def internal_check_capture_last(o)
    accepted_index = o.parameters.size() -1
    o.parameters.each_with_index do |p, index|
      if p.captures_rest && index != accepted_index
        acceptor.accept(Issues::CAPTURES_REST_NOT_LAST, p, {:param_name => p.name})
      end
    end
  end

  def internal_check_no_capture(o, container = o)
    o.parameters.each do |p|
      if p.captures_rest
        acceptor.accept(Issues::CAPTURES_REST_NOT_SUPPORTED, p, {:container => container, :param_name => p.name})
      end
    end
  end

  RESERVED_PARAMETERS = {
    'name' => true,
    'title' => true,
  }

  def internal_check_reserved_params(o)
    o.parameters.each do |p|
      if RESERVED_PARAMETERS[p.name]
        acceptor.accept(Issues::RESERVED_PARAMETER, p, {:container => o, :param_name => p.name})
      end
    end
  end

  def check_IfExpression(o)
    rvalue(o.test)
  end

  def check_KeyedEntry(o)
    rvalue(o.key)
    rvalue(o.value)
    # In case there are additional things to forbid than non-rvalues
    # acceptor.accept(Issues::ILLEGAL_EXPRESSION, o.key, :feature => 'hash key', :container => o.eContainer)
  end

  def check_LambdaExpression(o)
    internal_check_capture_last(o)
  end

  def check_LiteralList(o)
    o.values.each {|v| rvalue(v) }
  end

  def check_NodeDefinition(o)
    # Check that hostnames are valid hostnames (or regular expressions)
    hostname(o.host_matches, o)
    hostname(o.parent, o, 'parent') unless o.parent.nil?
    top(o.eContainer, o)
    if violator = ends_with_idem(o.body)
      acceptor.accept(Issues::IDEM_NOT_ALLOWED_LAST, violator, {:container => o})
    end
    unless o.parent.nil?
      acceptor.accept(Issues::ILLEGAL_NODE_INHERITANCE, o.parent)
    end
  end

  # No checking takes place - all expressions using a QualifiedName need to check. This because the
  # rules are slightly different depending on the container (A variable allows a numeric start, but not
  # other names). This means that (if the lexer/parser so chooses) a QualifiedName
  # can be anything when it represents a Bare Word and evaluates to a String.
  #
  def check_QualifiedName(o)
  end

  # Checks that the value is a valid UpperCaseWord (a CLASSREF), and optionally if it contains a hypen.
  # DOH: QualifiedReferences are created with LOWER CASE NAMES at parse time
  def check_QualifiedReference(o)
    # Is this a valid qualified name?
    if o.value !~ Puppet::Pops::Patterns::CLASSREF
      acceptor.accept(Issues::ILLEGAL_CLASSREF, o, {:name=>o.value})
    end
  end

  def check_QueryExpression(o)
    query(o.expr) if o.expr  # is optional
  end

  def relation_Object(o)
    rvalue(o)
  end

  def relation_CollectExpression(o); end

  def relation_RelationshipExpression(o); end

  def check_Parameter(o)
    if o.name =~ /^(?:0x)?[0-9]+$/
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
    relation(o.left_expr)
    relation(o.right_expr)
  end

  def check_ResourceExpression(o)
    # The expression for type name cannot be statically checked - this is instead done at runtime
    # to enable better error message of the result of the expression rather than the static instruction.
    # (This can be revised as there are static constructs that are illegal, but require updating many
    # tests that expect the detailed reporting).
  end

  def check_ResourceBody(o)
    seenUnfolding = false
    o.operations.each do |ao|
      if ao.is_a?(Puppet::Pops::Model::AttributesOperation)
        if seenUnfolding
          acceptor.accept(Issues::MULTIPLE_ATTRIBUTES_UNFOLD, ao)
        else
          seenUnfolding = true
        end
      end
    end
  end

  def check_ResourceDefaultsExpression(o)
    if o.form && o.form != :regular
      acceptor.accept(Issues::NOT_VIRTUALIZEABLE, o)
    end
  end

  def check_ResourceOverrideExpression(o)
    if o.form && o.form != :regular
      acceptor.accept(Issues::NOT_VIRTUALIZEABLE, o)
    end
  end

  def check_ReservedWord(o)
    acceptor.accept(Issues::RESERVED_WORD, o, :word => o.word)
  end

  def check_SelectorExpression(o)
    rvalue(o.left_expr)
  end

  def check_SelectorEntry(o)
    rvalue(o.matching_expr)
  end

  def check_UnaryExpression(o)
    rvalue(o.expr)
  end

  def check_UnlessExpression(o)
    rvalue(o.test)
    # TODO: Unless may not have an else part that is an IfExpression (grammar denies this though)
  end

  # Checks that variable is either strictly 0, or a non 0 starting decimal number, or a valid VAR_NAME
  def check_VariableExpression(o)
    # The expression must be a qualified name or an integer
    name_expr = o.expr
    return if name_expr.is_a?(Model::LiteralInteger)
    if !name_expr.is_a?(Model::QualifiedName)
      acceptor.accept(Issues::ILLEGAL_EXPRESSION, o, :feature => 'name', :container => o)
    else
      # name must be either a decimal string value, or a valid NAME
      name = o.expr.value
      if name[0,1] =~ /[0-9]/
        unless name =~ Puppet::Pops::Patterns::NUMERIC_VAR_NAME
          acceptor.accept(Issues::ILLEGAL_NUMERIC_VAR_NAME, o, :name => name)
        end
      else
        unless name =~ Puppet::Pops::Patterns::VAR_NAME
          acceptor.accept(Issues::ILLEGAL_VAR_NAME, o, :name => name)
        end
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

  def top_Program(o, definition)
    # ok
  end

  # A LambdaExpression is a BlockExpression, and this method is needed to prevent the polymorph method for BlockExpression
  # to accept a lambda.
  # A lambda can not iteratively create classes, nodes or defines as the lambda does not have a closure.
  #
  def top_LambdaExpression(o, definition)
    # fail, stop scanning parents
    acceptor.accept(Issues::NOT_TOP_LEVEL, definition)
  end

  #--IDEM CHECK
  def idem_Object(o)
    false
  end

  def idem_Nop(o)
    true
  end

  def idem_NilClass(o)
    true
  end

  def idem_Literal(o)
    true
  end

  def idem_LiteralList(o)
    true
  end

  def idem_LiteralHash(o)
    true
  end

  def idem_Factory(o)
    idem(o.current)
  end

  def idem_AccessExpression(o)
    true
  end

  def idem_BinaryExpression(o)
    true
  end

  def idem_RelationshipExpression(o)
    # Always side effect
    false
  end

  def idem_AssignmentExpression(o)
    # Always side effect
    false
  end

  # Handles UnaryMinusExpression, NotExpression, VariableExpression
  def idem_UnaryExpression(o)
    true
  end

  # Allow (no-effect parentheses) to be used around a productive expression
  def idem_ParenthesizedExpression(o)
    idem(o.expr)
  end

  def idem_RenderExpression(o)
    false
  end

  def idem_RenderStringExpression(o)
    false
  end

  def idem_BlockExpression(o)
    # productive if there is at least one productive expression
    ! o.statements.any? {|expr| !idem(expr) }
  end

  # Returns true even though there may be interpolated expressions that have side effect.
  # Report as idem anyway, as it is very bad design to evaluate an interpolated string for its
  # side effect only.
  def idem_ConcatenatedString(o)
    true
  end

  # Heredoc is just a string, but may contain interpolated string (which may have side effects).
  # This is still bad design and should be reported as idem.
  def idem_HeredocExpression(o)
    true
  end

  # May technically have side effects inside the Selector, but this is bad design - treat as idem
  def idem_SelectorExpression(o)
    true
  end

  def idem_IfExpression(o)
    [o.test, o.then_expr, o.else_expr].all? {|e| idem(e) }
  end

  # Case expression is idem, if test, and all options are idem
  def idem_CaseExpression(o)
    return false if !idem(o.test)
    ! o.options.any? {|opt| !idem(opt) }
  end

  # An option is idem if values and the then_expression are idem
  def idem_CaseOption(o)
    return false if o.values.any? { |value| !idem(value) }
    idem(o.then_expr)
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
