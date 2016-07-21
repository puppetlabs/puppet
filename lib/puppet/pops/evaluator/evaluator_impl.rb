require 'rgen/ecore/ecore'
require 'puppet/parser/scope'
require 'puppet/pops/evaluator/compare_operator'
require 'puppet/pops/evaluator/relationship_operator'
require 'puppet/pops/evaluator/access_operator'
require 'puppet/pops/evaluator/closure'
require 'puppet/pops/evaluator/external_syntax_support'
require 'puppet/pops/types/iterable'

module Puppet::Pops
module Evaluator
# This implementation of {Evaluator} performs evaluation using the puppet 3.x runtime system
# in a manner largely compatible with Puppet 3.x, but adds new features and introduces constraints.
#
# The evaluation uses _polymorphic dispatch_ which works by dispatching to the first found method named after
# the class or one of its super-classes. The EvaluatorImpl itself mainly deals with evaluation (it currently
# also handles assignment), and it uses a delegation pattern to more specialized handlers of some operators
# that in turn use polymorphic dispatch; this to not clutter EvaluatorImpl with too much responsibility).
#
# Since a pattern is used, only the main entry points are fully documented. The parameters _o_ and _scope_ are
# the same in all the polymorphic methods, (the type of the parameter _o_ is reflected in the method's name;
# either the actual class, or one of its super classes). The _scope_ parameter is always the scope in which
# the evaluation takes place. If nothing else is mentioned, the return is always the result of evaluation.
#
# See {Visitable} and {Visitor} for more information about
# polymorphic calling.
#
class EvaluatorImpl
  include Utils

  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Runtime3Support
  include ExternalSyntaxSupport

  COMMA_SEPARATOR = ', '.freeze

  # Reference to Issues name space makes it easier to refer to issues
  # (Issues are shared with the validator).
  #
  Issues = Issues

  def initialize
    @@eval_visitor     ||= Visitor.new(self, "eval", 1, 1)
    @@lvalue_visitor   ||= Visitor.new(self, "lvalue", 1, 1)
    @@assign_visitor   ||= Visitor.new(self, "assign", 3, 3)
    @@string_visitor   ||= Visitor.new(self, "string", 1, 1)

    @@type_calculator  ||= Types::TypeCalculator.new()

    @@compare_operator     ||= CompareOperator.new()
    @@relationship_operator ||= RelationshipOperator.new()

    # Use null migration checker unless given in context
    @migration_checker = (Puppet.lookup(:migration_checker) { Migration::MigrationChecker.new() })
  end

  # @api private
  def type_calculator
    @@type_calculator
  end

  # Evaluates the given _target_ object in the given scope.
  #
  # @overload evaluate(target, scope)
  # @param target [Object] evaluation target - see methods on the pattern assign_TYPE for actual supported types.
  # @param scope [Object] the runtime specific scope class where evaluation should take place
  # @return [Object] the result of the evaluation
  #
  # @api public
  #
  def evaluate(target, scope)
    begin
      @@eval_visitor.visit_this_1(self, target, scope)

    rescue SemanticError => e
      # A raised issue may not know the semantic target, use errors call stack, but fill in the
      # rest from a supplied semantic object, or the target instruction if there is not semantic
      # object.
      #
      fail(e.issue, e.semantic || target, e.options, e)

    rescue Puppet::PreformattedError => e
      # Already formatted with location information, and with the wanted call stack.
      # Note this is currently a specialized ParseError, so rescue-order is important
      #
      raise e

    rescue Puppet::ParseError => e
      # ParseError may be raised in ruby code without knowing the location
      # in puppet code.
      # Accept a ParseError that has file or line information available
      # as an error that should be used verbatim. (Tests typically run without
      # setting a file name).
      # ParseError can supply an original - it is impossible to determine which
      # call stack that should be propagated, using the ParseError's backtrace.
      #
      if e.file || e.line
        raise e
      else
        # Since it had no location information, treat it as user intended a general purpose
        # error. Pass on its call stack.
        fail(Issues::RUNTIME_ERROR, target, {:detail => e.message}, e)
      end


    rescue Puppet::Error => e
      # PuppetError has the ability to wrap an exception, if so, use the wrapped exception's
      # call stack instead
      fail(Issues::RUNTIME_ERROR, target, {:detail => e.message}, e.original || e)

    rescue StandardError => e
      # All other errors, use its message and call stack
      fail(Issues::RUNTIME_ERROR, target, {:detail => e.message}, e)
    end
  end

  # Assigns the given _value_ to the given _target_. The additional argument _o_ is the instruction that
  # produced the target/value tuple and it is used to set the origin of the result.
  #
  # @param target [Object] assignment target - see methods on the pattern assign_TYPE for actual supported types.
  # @param value [Object] the value to assign to `target`
  # @param o [Model::PopsObject] originating instruction
  # @param scope [Object] the runtime specific scope where evaluation should take place
  #
  # @api private
  #
  def assign(target, value, o, scope)
    @@assign_visitor.visit_this_3(self, target, value, o, scope)
  end

  # Computes a value that can be used as the LHS in an assignment.
  # @param o [Object] the expression to evaluate as a left (assignable) entity
  # @param scope [Object] the runtime specific scope where evaluation should take place
  #
  # @api private
  #
  def lvalue(o, scope)
    @@lvalue_visitor.visit_this_1(self, o, scope)
  end

  # Produces a String representation of the given object _o_ as used in interpolation.
  # @param o [Object] the expression of which a string representation is wanted
  # @param scope [Object] the runtime specific scope where evaluation should take place
  #
  # @api public
  #
  def string(o, scope)
    @@string_visitor.visit_this_1(self, o, scope)
  end

  # Evaluate a BlockExpression in a new scope with variables bound to the
  # given values.
  #
  # @param scope [Puppet::Parser::Scope] the parent scope
  # @param variable_bindings [Hash{String => Object}] the variable names and values to bind (names are keys, bound values are values)
  # @param block [Model::BlockExpression] the sequence of expressions to evaluate in the new scope
  #
  # @api private
  #
  def evaluate_block_with_bindings(scope, variable_bindings, block_expr)
    scope.with_guarded_scope do
      # change to create local scope_from - cannot give it file and line -
      # that is the place of the call, not "here"
      create_local_scope_from(variable_bindings, scope)
      evaluate(block_expr, scope)
    end
  end

  protected

  def lvalue_VariableExpression(o, scope)
    # evaluate the name
    evaluate(o.expr, scope)
  end

  # Catches all illegal lvalues
  #
  def lvalue_Object(o, scope)
    fail(Issues::ILLEGAL_ASSIGNMENT, o)
  end

  # An array is assignable if all entries are lvalues
  def lvalue_LiteralList(o, scope)
    o.values.map {|x| lvalue(x, scope) }
  end

  # Assign value to named variable.
  # The '$' sign is never part of the name.
  # @example In Puppet DSL
  #   $name = value
  # @param name [String] name of variable without $
  # @param value [Object] value to assign to the variable
  # @param o [Model::PopsObject] originating instruction
  # @param scope [Object] the runtime specific scope where evaluation should take place
  # @return [value<Object>]
  #
  def assign_String(name, value, o, scope)
    if name =~ /::/
      fail(Issues::CROSS_SCOPE_ASSIGNMENT, o.left_expr, {:name => name})
    end
    set_variable(name, value, o, scope)
    value
  end

  def assign_Numeric(n, value, o, scope)
    fail(Issues::ILLEGAL_NUMERIC_ASSIGNMENT, o.left_expr, {:varname => n.to_s})
  end

  # Catches all illegal assignment (e.g. 1 = 2, {'a'=>1} = 2, etc)
  #
  def assign_Object(name, value, o, scope)
    fail(Issues::ILLEGAL_ASSIGNMENT, o)
  end

  def assign_Array(lvalues, values, o, scope)
    if values.is_a?(Hash)
      lvalues.map do |lval|
        assign(lval,
          values.fetch(lval) {|k| fail(Issues::MISSING_MULTI_ASSIGNMENT_KEY, o, :key =>k)},
          o, scope)
      end
    elsif values.is_a?(Puppet::Pops::Types::PHostClassType)
      # assign variables from class variables
      # lookup class resource and return one or more parameter values
      # TODO: behavior when class_name is nil
      resource = find_resource(scope, 'class', values.class_name)
      if resource
        base_name = "#{values.class_name.downcase}::"
        idx = -1
        result = lvalues.map do |lval|
          idx += 1
          varname = "#{base_name}#{lval}"
          if variable_exists?(varname, scope)
            result = get_variable_value(varname, o, scope)
            assign(lval, result, o, scope)
          else
            fail(Puppet::Pops::Issues::MISSING_MULTI_ASSIGNMENT_VARIABLE, o.left_expr.values[idx], {:name => varname})
          end
        end
      else
        fail(Issues::UNKNOWN_RESOURCE, o.right_expr, {:type_name => 'Class', :title => values.class_name})
      end

    else
      values = [values] unless values.is_a?(Array)
      if values.size != lvalues.size
        fail(Issues::ILLEGAL_MULTI_ASSIGNMENT_SIZE, o, :expected =>lvalues.size, :actual => values.size)
      end
      lvalues.zip(values).map { |lval, val| assign(lval, val, o, scope) }
    end
  end

  def eval_Factory(o, scope)
    evaluate(o.current, scope)
  end

  # Evaluates any object not evaluated to something else to itself.
  def eval_Object o, scope
    o
  end

  # Allows nil to be used as a Nop, Evaluates to nil
  def eval_NilClass(o, scope)
    nil
  end

  # Evaluates Nop to nil.
  def eval_Nop(o, scope)
    nil
  end

  # Captures all LiteralValues not handled elsewhere.
  #
  def eval_LiteralValue(o, scope)
    o.value
  end

  # Reserved Words fail to evaluate
  #
  def eval_ReservedWord(o, scope)
    if !o.future
      fail(Issues::RESERVED_WORD, o, {:word => o.word})
    else
      o.word
    end
  end

  def eval_LiteralDefault(o, scope)
    :default
  end

  def eval_LiteralUndef(o, scope)
    nil
  end

  # A QualifiedReference (i.e. a  capitalized qualified name such as Foo, or Foo::Bar) evaluates to a PType
  #
  def eval_QualifiedReference(o, scope)
    type = Types::TypeParser.singleton.interpret(o, scope)
    fail(Issues::UNKNOWN_RESOURCE_TYPE, o, {:type_name => type.type_string }) if type.is_a?(Types::PTypeReferenceType)
    type
  end

  def eval_NotExpression(o, scope)
    ! is_true?(evaluate(o.expr, scope), o.expr)
  end

  def eval_UnaryMinusExpression(o, scope)
    - coerce_numeric(evaluate(o.expr, scope), o, scope)
  end

  def eval_UnfoldExpression(o, scope)
    candidate = evaluate(o.expr, scope)
    case candidate
    when nil
      []
    when Array
      candidate
    when Hash
      candidate.to_a
    when Puppet::Pops::Types::Iterator
      candidate.to_a
    else
      # turns anything else into an array (so result can be unfolded)
      [candidate]
    end
  end

  # Abstract evaluation, returns array [left, right] with the evaluated result of left_expr and
  # right_expr
  # @return <Array<Object, Object>> array with result of evaluating left and right expressions
  #
  def eval_BinaryExpression o, scope
    [ evaluate(o.left_expr, scope), evaluate(o.right_expr, scope) ]
  end

  # Evaluates assignment with operators =, +=, -= and
  #
  # @example Puppet DSL
  #   $a = 1
  #   $a += 1
  #   $a -= 1
  #
  def eval_AssignmentExpression(o, scope)
    name = lvalue(o.left_expr, scope)
    value = evaluate(o.right_expr, scope)

    if o.operator == :'='
      assign(name, value, o, scope)
    else
      fail(Issues::UNSUPPORTED_OPERATOR, o, {:operator => o.operator})
    end
    value
  end

  ARITHMETIC_OPERATORS = [:'+', :'-', :'*', :'/', :'%', :'<<', :'>>']
  COLLECTION_OPERATORS = [:'+', :'-', :'<<']

  # Handles binary expression where lhs and rhs are array/hash or numeric and operator is +, - , *, % / << >>
  #
  def eval_ArithmeticExpression(o, scope)
    left = evaluate(o.left_expr, scope)
    right = evaluate(o.right_expr, scope)

    begin
      result = calculate(left, right, o.operator, o.left_expr, o.right_expr, scope)
    rescue ArgumentError => e
      fail(Issues::RUNTIME_ERROR, o, {:detail => e.message}, e)
    end
    result
  end


  # Handles binary expression where lhs and rhs are array/hash or numeric and operator is +, - , *, % / << >>
  #
  def calculate(left, right, operator, left_o, right_o, scope)
    unless ARITHMETIC_OPERATORS.include?(operator)
      fail(Issues::UNSUPPORTED_OPERATOR, left_o.eContainer, {:operator => o.operator})
    end

    if (left.is_a?(Array) || left.is_a?(Hash)) && COLLECTION_OPERATORS.include?(operator)
      # Handle operation on collections
      case operator
      when :'+'
        concatenate(left, right)
      when :'-'
        delete(left, right)
      when :'<<'
        unless left.is_a?(Array)
          fail(Issues::OPERATOR_NOT_APPLICABLE, left_o, {:operator => operator, :left_value => left})
        end
        left + [right]
      end
    else
      # Handle operation on numeric
      left = coerce_numeric(left, left_o, scope)
      right = coerce_numeric(right, right_o, scope)
      begin
        if operator == :'%' && (left.is_a?(Float) || right.is_a?(Float))
          # Deny users the fun of seeing severe rounding errors and confusing results
          fail(Issues::OPERATOR_NOT_APPLICABLE, left_o, {:operator => operator, :left_value => left})
        end
        result = left.send(operator, right)
      rescue NoMethodError => e
        fail(Issues::OPERATOR_NOT_APPLICABLE, left_o, {:operator => operator, :left_value => left})
      rescue ZeroDivisionError => e
        fail(Issues::DIV_BY_ZERO, right_o)
      end
      if result == Float::INFINITY || result == -Float::INFINITY
        fail(Issues::RESULT_IS_INFINITY, left_o, {:operator => operator})
      end
      result
    end
  end

  def eval_EppExpression(o, scope)
    scope["@epp"] = []
    evaluate(o.body, scope)
    result = scope["@epp"].join
    result
  end

  def eval_RenderStringExpression(o, scope)
    scope["@epp"] << o.value.dup
    nil
  end

  def eval_RenderExpression(o, scope)
    scope["@epp"] << string(evaluate(o.expr, scope), scope)
    nil
  end

  # Evaluates Puppet DSL ->, ~>, <-, and <~
  def eval_RelationshipExpression(o, scope)
    # First level evaluation, reduction to basic data types or puppet types, the relationship operator then translates this
    # to the final set of references (turning strings into references, which can not naturally be done by the main evaluator since
    # all strings should not be turned into references.
    #
    real = eval_BinaryExpression(o, scope)
    @@relationship_operator.evaluate(real, o, scope)
  end

  # Evaluates x[key, key, ...]
  #
  def eval_AccessExpression(o, scope)
    left = evaluate(o.left_expr, scope)
    keys = o.keys || []
    if left.is_a?(Types::PHostClassType)
      # Evaluate qualified references without errors no undefined types
      keys = keys.map {|key| key.is_a?(Model::QualifiedReference) ? Types::TypeParser.singleton.interpret(key, scope) : evaluate(key, scope) }
    else
      keys = keys.map {|key| evaluate(key, scope) }
      # Resource[File] becomes File
      return keys[0] if Types::PResourceType::DEFAULT == left && keys.size == 1 && keys[0].is_a?(Types::PResourceType)
    end
    AccessOperator.new(o).access(left, scope, *keys)
  end

  # Evaluates <, <=, >, >=, and ==
  #
  def eval_ComparisonExpression o, scope
    left = evaluate(o.left_expr, scope)
    right = evaluate(o.right_expr, scope)

    begin
    # Left is a type
    if left.is_a?(Types::PAnyType)
      case o.operator
      when :'=='
        @@type_calculator.equals(left,right)

      when :'!='
        !@@type_calculator.equals(left,right)

      when :'<'
        # left can be assigned to right, but they are not equal
        @@type_calculator.assignable?(right, left) && ! @@type_calculator.equals(left,right)
      when :'<='
        # left can be assigned to right
        @@type_calculator.assignable?(right, left)
      when :'>'
        # right can be assigned to left, but they are not equal
        @@type_calculator.assignable?(left,right) && ! @@type_calculator.equals(left,right)
      when :'>='
        # right can be assigned to left
        @@type_calculator.assignable?(left, right)
      else
        fail(Issues::UNSUPPORTED_OPERATOR, o, {:operator => o.operator})
      end
    else
      case o.operator
      when :'=='
        @@compare_operator.equals(left,right)
      when :'!='
        ! @@compare_operator.equals(left,right)
      when :'<'
        @@compare_operator.compare(left,right) < 0
      when :'<='
        @@compare_operator.compare(left,right) <= 0
      when :'>'
        @@compare_operator.compare(left,right) > 0
      when :'>='
        @@compare_operator.compare(left,right) >= 0
      else
        fail(Issues::UNSUPPORTED_OPERATOR, o, {:operator => o.operator})
      end
    end
    rescue ArgumentError => e
      fail(Issues::COMPARISON_NOT_POSSIBLE, o, {
        :operator => o.operator,
        :left_value => left,
        :right_value => right,
        :detail => e.message}, e)
    end
  end

  # Evaluates matching expressions with type, string or regexp rhs expression.
  # If RHS is a type, the =~ matches compatible (instance? of) type.
  #
  # @example
  #   x =~ /abc.*/
  # @example
  #   x =~ "abc.*/"
  # @example
  #   y = "abc"
  #   x =~ "${y}.*"
  # @example
  #   [1,2,3] =~ Array[Integer[1,10]]
  #
  # Note that a string is not instance? of Regexp, only Regular expressions are.
  # The Pattern type should instead be used as it is specified as subtype of String.
  #
  # @return [Boolean] if a match was made or not. Also sets $0..$n to matchdata in current scope.
  #
  def eval_MatchExpression o, scope
    left = evaluate(o.left_expr, scope)
    pattern = evaluate(o.right_expr, scope)

    # matches RHS types as instance of for all types except a parameterized Regexp[R]
    if pattern.is_a?(Types::PAnyType)
      # evaluate as instance? of type check
      matched = pattern.instance?(left)
      # convert match result to Boolean true, or false
      return o.operator == :'=~' ? !!matched : !matched
    end

    if pattern.is_a?(Semantic::VersionRange)
      # evaluate if range includes version
      matched = Types::PSemVerRangeType.include?(pattern, left)
      return o.operator == :'=~' ? matched : !matched
    end

    begin
      pattern = Regexp.new(pattern) unless pattern.is_a?(Regexp)
    rescue StandardError => e
      fail(Issues::MATCH_NOT_REGEXP, o.right_expr, {:detail => e.message}, e)
    end
    unless left.is_a?(String)
      fail(Issues::MATCH_NOT_STRING, o.left_expr, {:left_value => left})
    end

    matched = pattern.match(left) # nil, or MatchData
    set_match_data(matched,scope) # creates ephemeral

    # convert match result to Boolean true, or false
    o.operator == :'=~' ? !!matched : !matched
  end

  # Evaluates Puppet DSL `in` expression
  #
  def eval_InExpression o, scope
    left = evaluate(o.left_expr, scope)
    right = evaluate(o.right_expr, scope)
    @@compare_operator.include?(right, left, scope)
  end

  # @example
  #   $a and $b
  # b is only evaluated if a is true
  #
  def eval_AndExpression o, scope
    is_true?(evaluate(o.left_expr, scope), o.left_expr) ? is_true?(evaluate(o.right_expr, scope), o.right_expr) : false
  end

  # @example
  #   a or b
  # b is only evaluated if a is false
  #
  def eval_OrExpression o, scope
    is_true?(evaluate(o.left_expr, scope), o.left_expr) ? true : is_true?(evaluate(o.right_expr, scope), o.right_expr)
  end

  # Evaluates each entry of the literal list and creates a new Array
  # Supports unfolding of entries
  # @return [Array] with the evaluated content
  #
  def eval_LiteralList o, scope
    unfold([], o.values, scope)
  end

  # Evaluates each entry of the literal hash and creates a new Hash.
  # @return [Hash] with the evaluated content
  #
  def eval_LiteralHash o, scope
    # optimized
    o.entries.reduce({}) {|h,entry| h[evaluate(entry.key, scope)] = evaluate(entry.value, scope); h }
  end

  # Evaluates all statements and produces the last evaluated value
  #
  def eval_BlockExpression o, scope
    r = nil
    o.statements.each {|s| r = evaluate(s, scope)}
    r
  end

  # Performs optimized search over case option values, lazily evaluating each
  # until there is a match. If no match is found, the case expression's default expression
  # is evaluated (it may be nil or Nop if there is no default, thus producing nil).
  # If an option matches, the result of evaluating that option is returned.
  # @return [Object, nil] what a matched option returns, or nil if nothing matched.
  #
  def eval_CaseExpression(o, scope)
    # memo scope level before evaluating test - don't want a match in the case test to leak $n match vars
    # to expressions after the case expression.
    #
    scope.with_guarded_scope do
      test = evaluate(o.test, scope)

      result = nil
      the_default = nil
      if o.options.find do |co|
        # the first case option that matches
        if co.values.find do |c|
          c = unwind_parentheses(c)
          case c
          when Model::LiteralDefault
            the_default = co.then_expr
            next false
          when Model::UnfoldExpression
            # not ideal for error reporting, since it is not known which unfolded result
            # that caused an error - the entire unfold expression is blamed (i.e. the var c, passed to is_match?)
            evaluate(c, scope).any? {|v| is_match?(test, v, c, co, scope) }
          else
            is_match?(test, evaluate(c, scope), c, co, scope)
          end
        end
        result = evaluate(co.then_expr, scope)
        true # the option was picked
        end
      end
        result # an option was picked, and produced a result
      else
        evaluate(the_default, scope) # evaluate the default (should be a nop/nil) if there is no default).
      end
    end
  end

  # Evaluates a CollectExpression by creating a collector transformer. The transformer
  # will evaulate the collection, create the appropriate collector, and hand it off
  # to the compiler to collect the resources specified by the query.
  #
  def eval_CollectExpression o, scope
    if o.query.is_a?(Model::ExportedQuery)
      optionally_fail(Issues::RT_NO_STORECONFIGS, o);
    end
    CollectorTransformer.new().transform(o,scope)
  end

  def eval_ParenthesizedExpression(o, scope)
    evaluate(o.expr, scope)
  end

  # This evaluates classes, nodes and resource type definitions to nil, since 3x:
  # instantiates them, and evaluates their parameters and body. This is achieved by
  # providing bridge AST classes in Puppet::Parser::AST::PopsBridge that bridges a
  # Pops Program and a Pops Expression.
  #
  # Since all Definitions are handled "out of band", they are treated as a no-op when
  # evaluated.
  #
  def eval_Definition(o, scope)
    nil
  end

  def eval_Program(o, scope)
    evaluate(o.body, scope)
  end

  # Produces Array[PAnyType], an array of resource references
  #
  def eval_ResourceExpression(o, scope)
    exported = o.exported
    virtual = o.virtual

    # Get the type name
    type_name =
    if (tmp_name = o.type_name).is_a?(Model::QualifiedName)
      tmp_name.value # already validated as a name
    else
      type_name_acceptable =
      case o.type_name
      when Model::QualifiedReference
        true
      when Model::AccessExpression
        o.type_name.left_expr.is_a?(Model::QualifiedReference)
      end

      evaluated_name = evaluate(tmp_name, scope)
      unless type_name_acceptable
        actual = type_calculator.generalize(type_calculator.infer(evaluated_name)).to_s
        fail(Issues::ILLEGAL_RESOURCE_TYPE, o.type_name, {:actual => actual})
      end

      # must be a CatalogEntry subtype
      case evaluated_name
      when Types::PHostClassType
        unless evaluated_name.class_name.nil?
          fail(Issues::ILLEGAL_RESOURCE_TYPE, o.type_name, {:actual=> evaluated_name.to_s})
        end
        'class'

      when Types::PResourceType
        unless evaluated_name.title().nil?
          fail(Issues::ILLEGAL_RESOURCE_TYPE, o.type_name, {:actual=> evaluated_name.to_s})
        end
        evaluated_name.type_name # assume validated

      when Types::PTypeReferenceType
        fail(Issues::UNKNOWN_RESOURCE_TYPE, o.type_string, {:type_name => evaluated_name.to_s})

      else
        actual = type_calculator.generalize(type_calculator.infer(evaluated_name)).to_s
        fail(Issues::ILLEGAL_RESOURCE_TYPE, o.type_name, {:actual=>actual})
      end
    end

    # This is a runtime check - the model is valid, but will have runtime issues when evaluated
    # and storeconfigs is not set.
    if(o.exported)
      optionally_fail(Issues::RT_NO_STORECONFIGS_EXPORT, o);
    end

    titles_to_body = {}
    body_to_titles = {}
    body_to_params = {}

    # titles are evaluated before attribute operations
    o.bodies.map do | body |
      titles = evaluate(body.title, scope)

      # Title may not be nil
      # Titles may be given as an array, it is ok if it is empty, but not if it contains nil entries
      # Titles may not be an empty String
      # Titles must be unique in the same resource expression
      # There may be a :default entry, its entries apply with lower precedence
      #
      if titles.nil?
        fail(Issues::MISSING_TITLE, body.title)
      end
      titles = [titles].flatten

      # Check types of evaluated titles and duplicate entries
      titles.each_with_index do |title, index|
        if title.nil?
          fail(Issues::MISSING_TITLE_AT, body.title, {:index => index})

        elsif !title.is_a?(String) && title != :default
          actual = type_calculator.generalize(type_calculator.infer(title)).to_s
          fail(Issues::ILLEGAL_TITLE_TYPE_AT, body.title, {:index => index, :actual => actual})

        elsif title == EMPTY_STRING
         fail(Issues::EMPTY_STRING_TITLE_AT, body.title, {:index => index})

        elsif titles_to_body[title]
          fail(Issues::DUPLICATE_TITLE, o, {:title => title})
        end
        titles_to_body[title] = body
      end

      # Do not create a real instance from the :default case
      titles.delete(:default)

      body_to_titles[body] = titles

      # Store evaluated parameters in a hash associated with the body, but do not yet create resource
      # since the entry containing :defaults may appear later
      body_to_params[body] = body.operations.reduce({}) do |param_memo, op|
        params = evaluate(op, scope)
        params = [params] unless params.is_a?(Array)
        params.each do |p|
          if param_memo.include? p.name
            fail(Issues::DUPLICATE_ATTRIBUTE, o, {:attribute => p.name})
          end
          param_memo[p.name] = p
        end
        param_memo
      end
    end

    # Titles and Operations have now been evaluated and resources can be created
    # Each production is a PResource, and an array of all is produced as the result of
    # evaluating the ResourceExpression.
    #
    defaults_hash = body_to_params[titles_to_body[:default]] || {}
    o.bodies.map do | body |
      titles = body_to_titles[body]
      params = defaults_hash.merge(body_to_params[body] || {})
      create_resources(o, scope, virtual, exported, type_name, titles, params.values)
    end.flatten.compact
  end

  def eval_ResourceOverrideExpression(o, scope)
    evaluated_resources = evaluate(o.resources, scope)
    evaluated_parameters = o.operations.map { |op| evaluate(op, scope) }
    create_resource_overrides(o, scope, [evaluated_resources].flatten, evaluated_parameters)
    evaluated_resources
  end

  # Produces 3x parameter
  def eval_AttributeOperation(o, scope)
    create_resource_parameter(o, scope, o.attribute_name, evaluate(o.value_expr, scope), o.operator)
  end

  def eval_AttributesOperation(o, scope)
    hashed_params = evaluate(o.expr, scope)
    unless hashed_params.is_a?(Hash)
      actual = type_calculator.generalize(type_calculator.infer(hashed_params)).to_s
      fail(Issues::TYPE_MISMATCH, o.expr, {:expected => 'Hash', :actual => actual})
    end
    hashed_params.map { |k,v| create_resource_parameter(o, scope, k, v, :'=>') }
  end

  # Sets default parameter values for a type, produces the type
  #
  def eval_ResourceDefaultsExpression(o, scope)
    type = evaluate(o.type_ref, scope)
    type_name =
    if type.is_a?(Types::PResourceType) && !type.type_name.nil? && type.title.nil?
      type.type_name # assume it is a valid name
    else
      actual = type_calculator.generalize(type_calculator.infer(type))
      fail(Issues::ILLEGAL_RESOURCE_TYPE, o.type_ref, {:actual => actual})
    end
    evaluated_parameters = o.operations.map {|op| evaluate(op, scope) }
    create_resource_defaults(o, scope, type_name, evaluated_parameters)
    # Produce the type
    type
  end

  # Evaluates function call by name.
  #
  def eval_CallNamedFunctionExpression(o, scope)
    # If LHS is a type (i.e. Integer, or Integer[...]
    # the call is taken as an instantiation of the given type
    #
    functor = o.functor_expr
    if functor.is_a?(Model::QualifiedReference) ||
      functor.is_a?(Model::AccessExpression) && functor.left_expr.is_a?(Model::QualifiedReference)
      # instantiation
      type = evaluate(functor, scope)
      return call_function_with_block('new', unfold([type], o.arguments || [], scope), o, scope)
    end

    # The functor expression is not evaluated, it is not possible to select the function to call
    # via an expression like $a()
    case functor
    when Model::QualifiedName
      # ok
    when Model::RenderStringExpression
      # helpful to point out this easy to make Epp error
      fail(Issues::ILLEGAL_EPP_PARAMETERS, o)
    else
      fail(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function name', :container => o})
    end
    name = o.functor_expr.value
    call_function_with_block(name, unfold([], o.arguments, scope), o, scope)
  end

  # Evaluation of CallMethodExpression handles a NamedAccessExpression functor (receiver.function_name)
  #
  def eval_CallMethodExpression(o, scope)
    unless o.functor_expr.is_a? Model::NamedAccessExpression
      fail(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function accessor', :container => o})
    end
    receiver = unfold([], [o.functor_expr.left_expr], scope)
    name = o.functor_expr.right_expr
    unless name.is_a? Model::QualifiedName
      fail(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function name', :container => o})
    end
    name = name.value # the string function name

    obj = receiver[0]
    receiver_type = Types::TypeCalculator.infer(obj)
    if receiver_type.is_a?(Types::PObjectType)
      member = receiver_type[name]
      unless member.nil?
        args = unfold([], o.arguments || [], scope)
        return o.lambda.nil? ? member.invoke(obj, scope, args) : member.invoke(obj, scope, args, &proc_from_lambda(o.lambda, scope))
      end
    end

    call_function_with_block(name, unfold(receiver, o.arguments || [], scope), o, scope)
  end

  def call_function_with_block(name, evaluated_arguments, o, scope)
    if o.lambda.nil?
      call_function(name, evaluated_arguments, o, scope)
    else
      call_function(name, evaluated_arguments, o, scope, &proc_from_lambda(o.lambda, scope))
    end
  end
  private :call_function_with_block

  def proc_from_lambda(lambda, scope)
    closure = Closure.new(self, lambda, scope)
    PuppetProc.new(closure) { |*args| closure.call(*args) }
  end
  private :proc_from_lambda

  # @example
  #   $x ? { 10 => true, 20 => false, default => 0 }
  #
  def eval_SelectorExpression o, scope
    # memo scope level before evaluating test - don't want a match in the case test to leak $n match vars
    # to expressions after the selector expression.
    #
    scope.with_guarded_scope do
      test = evaluate(o.left_expr, scope)

      the_default = nil
      selected = o.selectors.find do |s|
        me = unwind_parentheses(s.matching_expr)
        case me
        when Model::LiteralDefault
          the_default = s.value_expr
          false
        when Model::UnfoldExpression
          # not ideal for error reporting, since it is not known which unfolded result
          # that caused an error - the entire unfold expression is blamed (i.e. the var c, passed to is_match?)
          evaluate(me, scope).any? {|v| is_match?(test, v, me, s, scope) }
        else
          is_match?(test, evaluate(me, scope), me, s, scope)
        end
      end
      if selected
        evaluate(selected.value_expr, scope)
      elsif the_default
        evaluate(the_default, scope)
      else
        fail(Issues::UNMATCHED_SELECTOR, o.left_expr, :param_value => test)
      end
    end
  end

  # SubLocatable is simply an expression that holds location information
  def eval_SubLocatedExpression o, scope
    evaluate(o.expr, scope)
  end

  # Evaluates Puppet DSL Heredoc
  def eval_HeredocExpression o, scope
    result = evaluate(o.text_expr, scope)
    assert_external_syntax(scope, result, o.syntax, o.text_expr)
    result
  end

  # Evaluates Puppet DSL `if`
  def eval_IfExpression o, scope
    scope.with_guarded_scope do
      if is_true?(evaluate(o.test, scope), o.test)
        evaluate(o.then_expr, scope)
      else
        evaluate(o.else_expr, scope)
      end
    end
  end

  # Evaluates Puppet DSL `unless`
  def eval_UnlessExpression o, scope
    scope.with_guarded_scope do
      unless is_true?(evaluate(o.test, scope), o.test)
        evaluate(o.then_expr, scope)
      else
        evaluate(o.else_expr, scope)
      end
    end
  end

  # Evaluates a variable (getting its value)
  # The evaluator is lenient; any expression producing a String is used as a name
  # of a variable.
  #
  def eval_VariableExpression o, scope
    # Evaluator is not too fussy about what constitutes a name as long as the result
    # is a String and a valid variable name
    #
    name = evaluate(o.expr, scope)

    # Should be caught by validation, but make this explicit here as well, or mysterious evaluation issues
    # may occur for some evaluation use cases.
    case name
    when String
    when Numeric
    else
      fail(Issues::ILLEGAL_VARIABLE_EXPRESSION, o.expr)
    end
    get_variable_value(name, o, scope)
  end

  # Evaluates double quoted strings that may contain interpolation
  #
  def eval_ConcatenatedString o, scope
    o.segments.collect {|expr| string(evaluate(expr, scope), scope)}.join
  end


  # If the wrapped expression is a QualifiedName, it is taken as the name of a variable in scope.
  # Note that this is different from the 3.x implementation, where an initial qualified name
  # is accepted. (e.g. `"---${var + 1}---"` is legal. This implementation requires such concrete
  # syntax to be expressed in a model as `(TextExpression (+ (Variable var) 1)` - i.e. moving the decision to
  # the parser.
  #
  # Semantics; the result of an expression is turned into a string, nil is silently transformed to empty
  # string.
  # @return [String] the interpolated result
  #
  def eval_TextExpression o, scope
    if o.expr.is_a?(Model::QualifiedName)
      string(get_variable_value(o.expr.value, o, scope), scope)
    else
      string(evaluate(o.expr, scope), scope)
    end
  end

  def string_Object(o, scope)
    o.to_s
  end

  def string_Symbol(o, scope)
    if :undef == o  # optimized comparison 1.44 vs 1.95
      EMPTY_STRING
    else
      o.to_s
    end
  end

  def string_Array(o, scope)
    "[#{o.map {|e| string(e, scope)}.join(COMMA_SEPARATOR)}]"
  end

  def string_Hash(o, scope)
    "{#{o.map {|k,v| "#{string(k, scope)} => #{string(v, scope)}"}.join(COMMA_SEPARATOR)}}"
  end

  def string_Regexp(o, scope)
    "/#{o.source}/"
  end

  def string_PAnyType(o, scope)
    o.to_s
  end

  # Produces concatenation / merge of x and y.
  #
  # When x is an Array, y of type produces:
  #
  # * Array => concatenation `[1,2], [3,4] => [1,2,3,4]`
  # * Hash => concatenation of hash as array `[key, value, key, value, ...]`
  # * any other => concatenation of single value
  #
  # When x is a Hash, y of type produces:
  #
  # * Array => merge of array interpreted as `[key, value, key, value,...]`
  # * Hash => a merge, where entries in `y` overrides
  # * any other => error
  #
  # When x is something else, wrap it in an array first.
  #
  # When x is nil, an empty array is used instead.
  #
  # @note to concatenate an Array, nest the array - i.e. `[1,2], [[2,3]]`
  #
  # @overload concatenate(obj_x, obj_y)
  #   @param obj_x [Object] object to wrap in an array and concatenate to; see other overloaded methods for return type
  #   @param ary_y [Object] array to concatenate at end of `ary_x`
  #   @return [Object] wraps obj_x in array before using other overloaded option based on type of obj_y
  # @overload concatenate(ary_x, ary_y)
  #   @param ary_x [Array] array to concatenate to
  #   @param ary_y [Array] array to concatenate at end of `ary_x`
  #   @return [Array] new array with `ary_x` + `ary_y`
  # @overload concatenate(ary_x, hsh_y)
  #   @param ary_x [Array] array to concatenate to
  #   @param hsh_y [Hash] converted to array form, and concatenated to array
  #   @return [Array] new array with `ary_x` + `hsh_y` converted to array
  # @overload concatenate (ary_x, obj_y)
  #   @param ary_x [Array] array to concatenate to
  #   @param obj_y [Object] non array or hash object to add to array
  #   @return [Array] new array with `ary_x` + `obj_y` added as last entry
  # @overload concatenate(hsh_x, ary_y)
  #   @param hsh_x [Hash] the hash to merge with
  #   @param ary_y [Array] array interpreted as even numbered sequence of key, value merged with `hsh_x`
  #   @return [Hash] new hash with `hsh_x` merged with `ary_y` interpreted as hash in array form
  # @overload concatenate(hsh_x, hsh_y)
  #   @param hsh_x [Hash] the hash to merge to
  #   @param hsh_y [Hash] hash merged with `hsh_x`
  #   @return [Hash] new hash with `hsh_x` merged with `hsh_y`
  # @raise [ArgumentError] when `xxx_x` is neither an Array nor a Hash
  # @raise [ArgumentError] when `xxx_x` is a Hash, and `xxx_y` is neither Array nor Hash.
  #
  def concatenate(x, y)
    x = [x] unless x.is_a?(Array) || x.is_a?(Hash)
    case x
    when Array
      y = case y
      when Array then y
      when Hash  then y.to_a
      else
        [y]
      end
      x + y # new array with concatenation
    when Hash
      y = case y
      when Hash then y
      when Array
        # Hash[[a, 1, b, 2]] => {}
        # Hash[a,1,b,2] => {a => 1, b => 2}
        # Hash[[a,1], [b,2]] => {[a,1] => [b,2]}
        # Hash[[[a,1], [b,2]]] => {a => 1, b => 2}
        # Use type calcultor to determine if array is Array[Array[?]], and if so use second form
        # of call
        t = @@type_calculator.infer(y)
        if t.element_type.is_a? Types::PArrayType
          Hash[y]
        else
          Hash[*y]
        end
      else
        raise ArgumentError.new("Can only append Array or Hash to a Hash")
      end
      x.merge y # new hash with overwrite
    else
      raise ArgumentError.new("Can only append to an Array or a Hash.")
    end
  end

  # Produces the result x \ y (set difference)
  # When `x` is an Array, `y` is transformed to an array and then all matching elements removed from x.
  # When `x` is a Hash, all contained keys are removed from x as listed in `y` if it is an Array, or all its keys if it is a Hash.
  # The difference is returned. The given `x` and `y` are not modified by this operation.
  # @raise [ArgumentError] when `x` is neither an Array nor a Hash
  #
  def delete(x, y)
    result = x.dup
    case x
    when Array
      y = case y
      when Array then y
      when Hash then y.to_a
      else
        [y]
      end
      y.each {|e| result.delete(e) }
    when Hash
      y = case y
      when Array then y
      when Hash then y.keys
      else
        [y]
      end
      y.each {|e| result.delete(e) }
    else
      raise ArgumentError.new("Can only delete from an Array or Hash.")
    end
    result
  end

  # Implementation of case option matching.
  #
  # This is the type of matching performed in a case option, using == for every type
  # of value except regular expression where a match is performed.
  #
  def is_match?(left, right, o, option_expr, scope)
    @@compare_operator.match(left, right, scope)
  end

  # Maps the expression in the given array to their product except for UnfoldExpressions which are first unfolded.
  # The result is added to the given result Array.
  # @param result [Array] Where to add the result (may contain information to add to)
  # @param array [Array[Model::Expression] the expressions to map
  # @param scope [Puppet::Parser::Scope] the scope to evaluate in
  # @return [Array] the given result array with content added from the operation
  #
  def unfold(result, array, scope)
    array.each do |x|
      x = unwind_parentheses(x)
      if x.is_a?(Model::UnfoldExpression)
        result.concat(evaluate(x, scope))
      else
        result << evaluate(x, scope)
      end
    end
    result
  end
  private :unfold

  def unwind_parentheses(o)
    return o unless o.is_a?(Model::ParenthesizedExpression)
    unwind_parentheses(o.expr)
  end
  private :unwind_parentheses
end
end
end
