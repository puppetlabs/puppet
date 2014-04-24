require 'rgen/ecore/ecore'
require 'puppet/pops/evaluator/compare_operator'
require 'puppet/pops/evaluator/relationship_operator'
require 'puppet/pops/evaluator/access_operator'
require 'puppet/pops/evaluator/closure'
require 'puppet/pops/evaluator/external_syntax_support'

# This implementation of {Puppet::Pops::Evaluator} performs evaluation using the puppet 3.x runtime system
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
# See {Puppet::Pops::Visitable} and {Puppet::Pops::Visitor} for more information about
# polymorphic calling.
#
class Puppet::Pops::Evaluator::EvaluatorImpl
  include Puppet::Pops::Utils

  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support
  include Puppet::Pops::Evaluator::ExternalSyntaxSupport

  # This constant is not defined as Float::INFINITY in Ruby 1.8.7 (but is available in later version
  # Refactor when support is dropped for Ruby 1.8.7.
  #
  INFINITY = 1.0 / 0.0

  # Reference to Issues name space makes it easier to refer to issues
  # (Issues are shared with the validator).
  #
  Issues = Puppet::Pops::Issues

  def initialize
    @@eval_visitor   ||= Puppet::Pops::Visitor.new(self, "eval", 1, 1)
    @@lvalue_visitor   ||= Puppet::Pops::Visitor.new(self, "lvalue", 1, 1)
    @@assign_visitor   ||= Puppet::Pops::Visitor.new(self, "assign", 3, 3)
    @@string_visitor   ||= Puppet::Pops::Visitor.new(self, "string", 1, 1)

    @@type_calculator  ||= Puppet::Pops::Types::TypeCalculator.new()
    @@type_parser      ||= Puppet::Pops::Types::TypeParser.new()

    @@compare_operator     ||= Puppet::Pops::Evaluator::CompareOperator.new()
    @@relationship_operator ||= Puppet::Pops::Evaluator::RelationshipOperator.new()

    # Initialize the runtime module
    Puppet::Pops::Evaluator::Runtime3Support.instance_method(:initialize).bind(self).call()
  end

  # @api private
  def type_calculator
    @@type_calculator
  end

  # Polymorphic evaluate - calls eval_TYPE
  #
  # ## Polymorphic evaluate
  # Polymorphic evaluate calls a method on the format eval_TYPE where classname is the last
  # part of the class of the given _target_. A search is performed starting with the actual class, continuing
  # with each of the _target_ class's super classes until a matching method is found.
  #
  # # Description
  # Evaluates the given _target_ object in the given scope, optionally passing a block which will be
  # called with the result of the evaluation.
  #
  # @overload evaluate(target, scope, {|result| block})
  # @param target [Object] evaluation target - see methods on the pattern assign_TYPE for actual supported types.
  # @param scope [Object] the runtime specific scope class where evaluation should take place
  # @return [Object] the result of the evaluation
  #
  # @api
  #
  def evaluate(target, scope)
    begin
      @@eval_visitor.visit_this_1(self, target, scope)

    rescue Puppet::Pops::SemanticError => e
      # a raised issue may not know the semantic target
      fail(e.issue, e.semantic || target, e.options, e)

    rescue StandardError => e
      if e.is_a? Puppet::ParseError
        # ParseError's are supposed to be fully configured with location information
        raise e
      end
      fail(Issues::RUNTIME_ERROR, target, {:detail => e.message}, e)
    end
  end

  # Polymorphic assign - calls assign_TYPE
  #
  # ## Polymorphic assign
  # Polymorphic assign calls a method on the format assign_TYPE where TYPE is the last
  # part of the class of the given _target_. A search is performed starting with the actual class, continuing
  # with each of the _target_ class's super classes until a matching method is found.
  #
  # # Description
  # Assigns the given _value_ to the given _target_. The additional argument _o_ is the instruction that
  # produced the target/value tuple and it is used to set the origin of the result.
  # @param target [Object] assignment target - see methods on the pattern assign_TYPE for actual supported types.
  # @param value [Object] the value to assign to `target`
  # @param o [Puppet::Pops::Model::PopsObject] originating instruction
  # @param scope [Object] the runtime specific scope where evaluation should take place
  #
  # @api
  #
  def assign(target, value, o, scope)
    @@assign_visitor.visit_this_3(self, target, value, o, scope)
  end

  def lvalue(o, scope)
    @@lvalue_visitor.visit_this_1(self, o, scope)
  end

  def string(o, scope)
    @@string_visitor.visit_this_1(self, o, scope)
  end

  # Call a closure matching arguments by name - Can only be called with a Closure (for now), may be refactored later
  # to also handle other types of calls (function calls are also handled by CallNamedFunction and CallMethod, they
  # could create similar objects to Closure, wait until other types of defines are instantiated - they may behave
  # as special cases of calls - i.e. 'new').
  #
  # Call by name supports a "spill_over" mode where extra arguments in the given args_hash are introduced
  # as variables in the resulting scope.
  #
  # @raise ArgumentError, if there are to many or too few arguments
  # @raise ArgumentError, if given closure is not a Puppet::Pops::Evaluator::Closure
  #
  def call_by_name(closure, args_hash, scope, spill_over = false)
    raise ArgumentError, "Can only call a Lambda" unless closure.is_a?(Puppet::Pops::Evaluator::Closure)
    pblock = closure.model
    parameters = pblock.parameters || []

    if !spill_over && args_hash.size > parameters.size
      raise ArgumentError, "Too many arguments: #{args_hash.size} for #{parameters.size}" 
    end

    # associate values with parameters
    scope_hash = {}
    parameters.each do |p|
      scope_hash[p.name] = args_hash[p.name] || evaluate(p.value, scope)
    end
    missing = scope_hash.reduce([]) {|memo, entry| memo << entry[0] if entry[1].nil?; memo }
    unless missing.empty?
      optional = parameters.count { |p| !p.value.nil? }
      raise ArgumentError, "Too few arguments; no value given for required parameters #{missing.join(" ,")}"
    end
    if spill_over
      # all args from given hash should be used, nil entries replaced by default values should win
      scope_hash = args_hash.merge(scope_hash)
    end

    # Store the evaluated name => value associations in a new inner/local/ephemeral scope
    # (This is made complicated due to the fact that the implementation of scope is overloaded with
    # functionality and an inner ephemeral scope must be used (as opposed to just pushing a local scope
    # on a scope "stack").

    # Ensure variable exists with nil value if error occurs.
    # Some ruby implementations does not like creating variable on return
    result = nil
    begin
      scope_memo = get_scope_nesting_level(scope)
      # change to create local scope_from - cannot give it file and line - that is the place of the call, not
      # "here"
      create_local_scope_from(scope_hash, scope)
      result = evaluate(pblock.body, scope)
    ensure
      set_scope_nesting_level(scope, scope_memo)
    end
    result
  end

  # Call a closure - Can only be called with a Closure (for now), may be refactored later
  # to also handle other types of calls (function calls are also handled by CallNamedFunction and CallMethod, they
  # could create similar objects to Closure, wait until other types of defines are instantiated - they may behave
  # as special cases of calls - i.e. 'new')
  #
  # @raise ArgumentError, if there are to many or too few arguments
  # @raise ArgumentError, if given closure is not a Puppet::Pops::Evaluator::Closure
  #
  def call(closure, args, scope)
    raise ArgumentError, "Can only call a Lambda" unless closure.is_a?(Puppet::Pops::Evaluator::Closure)
    pblock = closure.model
    parameters = pblock.parameters || []

    raise ArgumentError, "Too many arguments: #{args.size} for #{parameters.size}" unless args.size <= parameters.size

    # associate values with parameters
    merged = parameters.zip(args)
    # calculate missing arguments
    missing = parameters.slice(args.size, parameters.size - args.size).select {|p| p.value.nil? }
    unless missing.empty?
      optional = parameters.count { |p| !p.value.nil? }
      raise ArgumentError, "Too few arguments; #{args.size} for #{optional > 0 ? ' min ' : ''}#{parameters.size - optional}"
    end

    evaluated = merged.collect do |m|
      # m can be one of
      # m = [Parameter{name => "name", value => nil], "given"]
      #   | [Parameter{name => "name", value => Expression}, "given"]
      #
      # "given" is always an optional entry. If a parameter was provided then
      # the entry will be in the array, otherwise the m array will be a
      # single element.
      given_argument = m[1]
      argument_name = m[0].name
      default_expression = m[0].value

      value = if default_expression
        evaluate(default_expression, scope)
      else
        given_argument
      end
      [argument_name, value]
    end

    # Store the evaluated name => value associations in a new inner/local/ephemeral scope
    # (This is made complicated due to the fact that the implementation of scope is overloaded with
    # functionality and an inner ephemeral scope must be used (as opposed to just pushing a local scope
    # on a scope "stack").

    # Ensure variable exists with nil value if error occurs. 
    # Some ruby implementations does not like creating variable on return
    result = nil
    begin
      scope_memo = get_scope_nesting_level(scope)
      # change to create local scope_from - cannot give it file and line - that is the place of the call, not
      # "here"
      create_local_scope_from(Hash[evaluated], scope)
      result = evaluate(pblock.body, scope)
    ensure
      set_scope_nesting_level(scope, scope_memo)
    end
    result
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

  # Assign value to named variable.
  # The '$' sign is never part of the name.
  # @example In Puppet DSL
  #   $name = value
  # @param name [String] name of variable without $
  # @param value [Object] value to assign to the variable
  # @param o [Puppet::Pops::Model::PopsObject] originating instruction
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

  def eval_Factory(o, scope)
    evaluate(o.current, scope)
  end

  # Evaluates any object not evaluated to something else to itself.
  def eval_Object o, scope
    o
  end

  # Allows nil to be used as a Nop.
  # Evaluates to nil
  # TODO: What is the difference between literal undef, nil, and nop?
  #
  def eval_NilClass(o, scope)
    nil
  end

  # Evaluates Nop to nil.
  # TODO: or is this the same as :undef
  # TODO: is this even needed as a separate instruction when there is a literal undef?
  def eval_Nop(o, scope)
    nil
  end

  # Captures all LiteralValues not handled elsewhere.
  #
  def eval_LiteralValue(o, scope)
    o.value
  end

  def eval_LiteralDefault(o, scope)
    :default
  end

  def eval_LiteralUndef(o, scope)
    :undef # TODO: or just use nil for this?
  end

  # A QualifiedReference (i.e. a  capitalized qualified name such as Foo, or Foo::Bar) evaluates to a PType
  #
  def eval_QualifiedReference(o, scope)
    @@type_parser.interpret(o)
  end

  def eval_NotExpression(o, scope)
    ! is_true?(evaluate(o.expr, scope))
  end

  def eval_UnaryMinusExpression(o, scope)
    - coerce_numeric(evaluate(o.expr, scope), o, scope)
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

    case o.operator
    when :'=' # regular assignment
      assign(name, value, o, scope)

    when :'+='
      # if value does not exist and strict is on, looking it up fails, else it is nil or :undef
      existing_value = get_variable_value(name, o, scope)
      begin
        if existing_value.nil? || existing_value == :undef
          assign(name, value, o, scope)
        else
          # Delegate to calculate function to deal with check of LHS, and perform ´+´ as arithmetic or concatenation the
          # same way as ArithmeticExpression performs `+`.
          assign(name, calculate(existing_value, value, :'+', o.left_expr, o.right_expr, scope), o, scope)
        end
      rescue ArgumentError => e
        fail(Issues::APPEND_FAILED, o, {:message => e.message})
      end

    when :'-='
      # If an attempt is made to delete values from something that does not exists, the value is :undef (it is guaranteed to not
      # include any values the user wants deleted anyway :-)
      #
      # if value does not exist and strict is on, looking it up fails, else it is nil or :undef
      existing_value = get_variable_value(name, o, scope)
      begin
      if existing_value.nil? || existing_value == :undef
        assign(name, :undef, o, scope)
      else
        # Delegate to delete function to deal with check of LHS, and perform deletion
        assign(name, delete(get_variable_value(name, o, scope), value), o, scope)
      end
      rescue ArgumentError => e
        fail(Issues::APPEND_FAILED, o, {:message => e.message}, e)
      end
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
    left, right = eval_BinaryExpression(o, scope)
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
      if result == INFINITY || result == -INFINITY
        fail(Issues::RESULT_IS_INFINITY, left_o, {:operator => operator})
      end
      result
    end
  end

  def eval_EppExpression(o, scope)
    scope["@epp"] = []
    evaluate(o.body, scope)
    result = scope["@epp"].join('')
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
    keys = o.keys.nil? ? [] : o.keys.collect {|key| evaluate(key, scope) }
    Puppet::Pops::Evaluator::AccessOperator.new(o).access(left, scope, *keys)
  end

  # Evaluates <, <=, >, >=, and ==
  #
  def eval_ComparisonExpression o, scope
    left, right = eval_BinaryExpression o, scope

    begin
    # Left is a type
    if left.is_a?(Puppet::Pops::Types::PAbstractType)
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
  # If RHS is a type, the =~ matches compatible (assignable?) type.
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
  # @return [Boolean] if a match was made or not. Also sets $0..$n to matchdata in current scope.
  #
  def eval_MatchExpression o, scope
    left, pattern = eval_BinaryExpression o, scope
    # matches RHS types as instance of for all types except a parameterized Regexp[R]
    if pattern.is_a?(Puppet::Pops::Types::PAbstractType)
      if pattern.is_a?(Puppet::Pops::Types::PRegexpType) && pattern.pattern
        # A qualified PRegexpType, get its ruby regexp
        pattern = pattern.regexp
      else
        # evaluate as instance?
        matched = @@type_calculator.instance?(pattern, left)
        # convert match result to Boolean true, or false
        return o.operator == :'=~' ? !!matched : !matched
      end
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
    set_match_data(matched, o, scope) # creates ephemeral

    # convert match result to Boolean true, or false
    o.operator == :'=~' ? !!matched : !matched
  end

  # Evaluates Puppet DSL `in` expression
  #
  def eval_InExpression o, scope
    left, right = eval_BinaryExpression o, scope
    @@compare_operator.include?(right, left)
  end

  # @example
  #   $a and $b
  # b is only evaluated if a is true
  #
  def eval_AndExpression o, scope
    is_true?(evaluate(o.left_expr, scope)) ? is_true?(evaluate(o.right_expr, scope)) : false
  end

  # @example
  #   a or b
  # b is only evaluated if a is false
  #
  def eval_OrExpression o, scope
    is_true?(evaluate(o.left_expr, scope)) ? true : is_true?(evaluate(o.right_expr, scope))
  end

  # Evaluates each entry of the literal list and creates a new Array
  # @return [Array] with the evaluated content
  #
  def eval_LiteralList o, scope
    o.values.collect {|expr| evaluate(expr, scope)}
  end

  # Evaluates each entry of the literal hash and creates a new Hash.
  # @return [Hash] with the evaluated content
  #
  def eval_LiteralHash o, scope
    h = Hash.new
    o.entries.each {|entry| h[ evaluate(entry.key, scope)]= evaluate(entry.value, scope)}
    h
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
    with_guarded_scope(scope) do
      test = evaluate(o.test, scope)
      result = nil
      the_default = nil
      if o.options.find do |co|
        # the first case option that matches
        if co.values.find do |c|
          the_default = co.then_expr if c.is_a? Puppet::Pops::Model::LiteralDefault
          is_match?(test, evaluate(c, scope), c, scope)
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

  # Evaluates a CollectExpression by transforming it into a 3x AST::Collection and then evaluating that.
  # This is done because of the complex API between compiler, indirector, backends, and difference between
  # collecting virtual resources and exported resources.
  #
  def eval_CollectExpression o, scope
    # The Collect Expression and its contained query expressions are implemented in such a way in
    # 3x that it is almost impossible to do anything about them (the AST objects are lazily evaluated,
    # and the built structure consists of both higher order functions and arrays with query expressions
    # that are either used as a predicate filter, or given to an indirection terminus (such as the Puppet DB
    # resource terminus). Unfortunately, the 3x implementation has many inconsistencies that the implementation
    # below carries forward.
    #
    collect_3x = Puppet::Pops::Model::AstTransformer.new().transform(o)
    collected = collect_3x.evaluate(scope)
    # the 3x returns an instance of Parser::Collector (but it is only registered with the compiler at this
    # point and does not contain any valuable information (like the result)
    # Dilemma: If this object is returned, it is a first class value in the Puppet Language and we
    # need to be able to perform operations on it. We can forbid it from leaking by making CollectExpression
    # a non R-value. This makes it possible for the evaluator logic to make use of the Collector.
    collected
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

  # Produces Array[PObjectType], an array of resource references
  #
  def eval_ResourceExpression(o, scope)
    exported = o.exported
    virtual = o.virtual
    type_name = evaluate(o.type_name, scope)
    o.bodies.map do |body|
      titles = [evaluate(body.title, scope)].flatten
      evaluated_parameters = body.operations.map {|op| evaluate(op, scope) }
      create_resources(o, scope, virtual, exported, type_name, titles, evaluated_parameters)
    end.flatten.compact
  end

  def eval_ResourceOverrideExpression(o, scope)
    evaluated_resources = evaluate(o.resources, scope)
    evaluated_parameters = o.operations.map { |op| evaluate(op, scope) }
    create_resource_overrides(o, scope, [evaluated_resources].flatten, evaluated_parameters)
    evaluated_resources
  end

  # Produces 3x array of parameters
  def eval_AttributeOperation(o, scope)
    create_resource_parameter(o, scope, o.attribute_name, evaluate(o.value_expr, scope), o.operator)
  end

  # Sets default parameter values for a type, produces the type
  #
  def eval_ResourceDefaultsExpression(o, scope)
    type_name = o.type_ref.value # a QualifiedName's string value
    evaluated_parameters = o.operations.map {|op| evaluate(op, scope) }
    create_resource_defaults(o, scope, type_name, evaluated_parameters)
    # Produce the type
    evaluate(o.type_ref, scope)
  end

  # Evaluates function call by name.
  #
  def eval_CallNamedFunctionExpression(o, scope)
    # The functor expression is not evaluated, it is not possible to select the function to call
    # via an expression like $a()
    case o.functor_expr
    when Puppet::Pops::Model::QualifiedName
      # ok
    when Puppet::Pops::Model::RenderStringExpression
      # helpful to point out this easy to make Epp error
      fail(Issues::ILLEGAL_EPP_PARAMETERS, o)
    else
      fail(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function name', :container => o})
    end
    name = o.functor_expr.value
    evaluated_arguments = o.arguments.collect {|arg| evaluate(arg, scope) }
    # wrap lambda in a callable block if it is present
    evaluated_arguments << Puppet::Pops::Evaluator::Closure.new(self, o.lambda, scope) if o.lambda
    call_function(name, evaluated_arguments, o, scope)
  end

  # Evaluation of CallMethodExpression handles a NamedAccessExpression functor (receiver.function_name)
  #
  def eval_CallMethodExpression(o, scope)
    unless o.functor_expr.is_a? Puppet::Pops::Model::NamedAccessExpression
      fail(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function accessor', :container => o})
    end
    receiver = evaluate(o.functor_expr.left_expr, scope)
    name = o.functor_expr.right_expr
    unless name.is_a? Puppet::Pops::Model::QualifiedName
      fail(Issues::ILLEGAL_EXPRESSION, o.functor_expr, {:feature=>'function name', :container => o})
    end 
    name = name.value # the string function name
    evaluated_arguments = [receiver] + (o.arguments || []).collect {|arg| evaluate(arg, scope) }
    evaluated_arguments << Puppet::Pops::Evaluator::Closure.new(self, o.lambda, scope) if o.lambda
    call_function(name, evaluated_arguments, o, scope)
  end

  # @example
  #   $x ? { 10 => true, 20 => false, default => 0 }
  #
  def eval_SelectorExpression o, scope
    # memo scope level before evaluating test - don't want a match in the case test to leak $n match vars
    # to expressions after the selector expression.
    #
    with_guarded_scope(scope) do
      test = evaluate(o.left_expr, scope)
      selected = o.selectors.find do |s|
        candidate = evaluate(s.matching_expr, scope)
        candidate == :default || is_match?(test, candidate, s.matching_expr, scope)
      end
      if selected
        evaluate(selected.value_expr, scope)
      else
        nil
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
    with_guarded_scope(scope) do
      if is_true?(evaluate(o.test, scope))
        evaluate(o.then_expr, scope)
      else
        evaluate(o.else_expr, scope)
      end
    end
  end

  # Evaluates Puppet DSL `unless`
  def eval_UnlessExpression o, scope
    with_guarded_scope(scope) do
      unless is_true?(evaluate(o.test, scope))
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
    # may occur.
    case name
    when String
    when Numeric
    else
      fail(Issues::ILLEGAL_VARIABLE_EXPRESSION, o.expr)
    end
    # TODO: Check for valid variable name (Task for validator)
    # TODO: semantics of undefined variable in scope, this just returns what scope does == value or nil
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
    if o.expr.is_a?(Puppet::Pops::Model::QualifiedName)
      # TODO: formalize, when scope returns nil, vs error
      string(get_variable_value(o.expr.value, o, scope), scope)
    else
      string(evaluate(o.expr, scope), scope)
    end
  end

  def string_Object(o, scope)
    o.to_s
  end

  def string_Symbol(o, scope)
    case o
    when :undef
      ''
    else
      o.to_s
    end
  end

  def string_Array(o, scope) 
    ['[', o.map {|e| string(e, scope)}.join(', '), ']'].join()
  end

  def string_Hash(o, scope)
    ['{', o.map {|k,v| string(k, scope) + " => " + string(v, scope)}.join(', '), '}'].join()
  end

  def string_Regexp(o, scope)
    ['/', o.source, '/'].join()
  end

  def string_PAbstractType(o, scope)
    @@type_calculator.string(o)
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
        if t.element_type.is_a? Puppet::Pops::Types::PArrayType
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
  def is_match? left, right, o, scope
    if right.is_a?(Regexp)
      return false unless left.is_a? String
      matched = right.match(left)
      set_match_data(matched, o, scope) # creates or clears ephemeral
      !!matched # convert to boolean
    elsif right.is_a?(Puppet::Pops::Types::PAbstractType)
      # right is a type and left is not - check if left is an instance of the given type
      # (The reverse is not terribly meaningful - computing which of the case options that first produces
      # an instance of a given type).
      #
      @@type_calculator.instance?(right, left)
    else
      # Handle equality the same way as the language '==' operator (case insensitive etc.)
      @@compare_operator.equals(left,right)
    end
  end

  def with_guarded_scope(scope)
    scope_memo = get_scope_nesting_level(scope)
    begin
      yield
    ensure
      set_scope_nesting_level(scope, scope_memo)
    end
  end

end
