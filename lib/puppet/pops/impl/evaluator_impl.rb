require 'puppet/pops/api'
require 'puppet/pops/impl/call_operator'
require 'puppet/pops/impl/compare_operator'
require 'puppet/pops/api/utils'

require 'rgen/ecore/ecore'

module Puppet; module Pops; module Impl

  # This implementation of {Puppet::Pops::API::Evaluator} performs evaluation, in a manner largely compatible with Puppet 3.x,
  # but adds new features and introduces constraints.
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
  # See {Puppet::Pops::API::Visitable} and {Puppet::Pops::API::Visitor} for more information about
  # polymorphic calling.
  # @api private
  #
  class EvaluatorImpl < Puppet::Pops::API::Evaluator
    include Puppet::Pops::API::Utils

    def initialize
      @eval_visitor ||= Visitor.new(self, "eval", 1, 1)
      @assign_visitor ||= Visitor.new(self, "assign", 3, 3)
      @call_operator ||= CallOperator.new
      @compare_operator ||= CompareOperator.new
    end
  
    # PolymorphiC evaluate - calls eval_TYPE
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
    # @param scope [Puppet::Pops::API::Scope] the scope where evaluation should take place
    # @return [Object] the result of the evaluation
    # @yieldparam [Object] the result of the evaluation of target
    # @yieldreturn [Object] the result of evaluating the optional block
    #
    # @api
    def evaluate(target, scope, &block)
      x = @eval_visitor.visit(target, scope)
      if block_given?
        block.call(x)
      else
        x
      end
    end
    
    
    # Fails the evaluation of _o_ in the given scope with the given message
    #
    # @status may need an extra parameter for error code
    # @param message [String] the error message
    # @param o [Object] the object for which evaluation failed in some way. Used to determine origin.
    # @param scope [Puppet::Pops::API::Scope] the scope in which evaluation failed
    # @return [!] this method does not return
    # @raise [Puppet::Pops::API::EvaluationError] an evaluation error initialized from the arguments
    # @todo fail evaluation with message, failure evaluating o, in scope
    # @todo This just fails with the message, should include a label for the expression
    #       and any origin set in an adapter for o. Scope could be passed for debugging
    #       purposes / stackdump
    #
    def fail message, o, scope
      raise Puppet::Pops::EvaluationError.new(message)
    end

    # Polymorphic assign - calls assign_TYPE.
    # 
    # # Polymorphic assign
    # Polymorphic assign calls a method on the format assign_TYPE where TYPE is the last
    # part of the class of the given _target_. A search is performed starting with the actual class, continuing
    # with each of the _target_ class's super classes until a matching method is found.
    # 
    # # Description
    # Assigns the given _value_ to the given _target_. The additional argument _o_ is the instruction that
    # produced the target/value tuple and it is used to set the origin of the result.
    # @param target [Object] assignment target - see methods on the pattern assign_TYPE for actual supported types. 
    # @param value [Object] the value to assign to `target` 
    # @param o [Puppet::Pops::API::Model::PopsObject] originating instruction
    # @param scope [Puppet::Pops::API::Scope] the scope where evaluation should take place

    def assign target, value, o, scope
      @assign_visitor.visit(target, value, o, scope)
    end
    
    protected
    
    # Assign value to named variable.
    # The '$' sign is never part of the name.
    # @todo origin needs to be passed to the setting of the variable in scope
    # @example In Puppet DSL
    #   $name = value
    # @param name [String] name of variable without $
    # @param value [Object] value to assign to the varible
    # @param o [Puppet::Pops::API::Model::PopsObject] originating instruction
    # @param scope [Puppet::Pops::API::Scope] the scope where evaluation should take place
    # @return [value<Object>]
    def assign_String(name, value, o, scope)
      # TODO, pass on origin from o
      scope.set_variable(name, value)
      value
    end
  
    # Assign value to named variables in an array. 
    # The '$' sign is never part of the name.
    # @todo setting matching name from value with keyed access (e.g. a hash). 
    # @example Puppet DSL has no concrete syntax 
    #   [a, b, c] = 10
    # @param names [Array<String>] array of variable names without $
    # @param value [Object] value to assign to each varible
    # @param o [Puppet::Pops::API::Model::PopsObject] originating instruction
    # @param scope [Puppet::Pops::API::Scope] the scope where evaluation should take place
    # @return [value<Object>]
    def assign_Array(names, value, o, scope)
      names.each {|x| scope.set_variable(x, value) }
      value
    end
    
    # Catch all evaluation.
    # Any object not evaluated to something else, evaluates to itself.
    def eval_Object o, scope
      o
    end
    
    # Allows nil to be used as a Nop.
    # Evaluates to nil
    def eval_NilClass o, scope
      nil
    end
    
    # Evaluates Nop to nil.
    def eval_Nop o, scope
      nil
    end
    
    # Captures all LiteralValues (including QualifiedName which many other expression want to
    # evaluate as a reference instead of a string value).
    #--
    # QualifiedName < LiteralValue  end
    # QualifiedReference < LiteralValue end
    def eval_LiteralValue o, scope
      o.value
    end
        
    def eval_LiteralDefault o, scope
      :default
    end
    
    def eval_LiteralUndef o, scope
      :undef # TODO: or just use nil for this?
    end
    
    def eval_NotExpression o, scope
      ! is_true?(evaluate(o.expr, scope))
    end
  
    def eval_UnaryMinusExpression o, scope
      - box_numeric(evaluate(o.expr, scope), o, scope)
    end
    
    # Abstract evaluation, returns array [left, right] with the evaluated result of left_expr and
    # right_expr
    def eval_BinaryExpression o, scope
      [] << evaluate(o.left_expr, scope) << evaluate(o.right_expr, scope)
    end
    
    # Evaluates assignment with operators =, +=, -= and []=
    #
    # @example Puppet DSL
    #   $a = 1
    #   $a += 1
    # @todo support for -= ('without' to remove from array) not yet implemented
    # @todo support for []= (for each assignment)
    # 
    def eval_AssignmentExpression o, scope
      case o.operator
      when :'=' # normal assignment
        assign(evaluate(o.left_expr, scope), evaluate(o.right_expr, scope), o, scope)
      when :'+=' 
        # concatenation current + value
          name = evaluate(o.left_expr, scope)
          unless scope.get_variable_entry(name)
            fail("Can not append to undefined variable: '#{name}'", o, scope)
          end
          value = evaluate(o.right_expr, scope)
          begin
            result = concatenate(scope.get_variable_entry(name).value, value)
            assign(name, result, o, scope)
          rescue ArgumentError => e
            fail("Assignment += failed with error: #{e.message}", o, scope)
          end
      when :'-=' 
        # current without value(s)
        # TODO
        fail "Not Implemented Yet: operator: '#{o.operator}'.", o, scope
  
      when :'[]=' 
        # for each, a new variable mapped to name in value responding to []
        # TODO
        fail "Not Implemented Yet: operator: '#{o.operator}'.", o, scope
            
      else 
        fail "Unknown operator: '#{o.operator}'.", o, scope
      end
    end
  
    # Handles binary expression where lhs and rhs are numeric and operator is +, - , * /
    # 
    def eval_ArithmeticExpression o, scope
      left = box_numeric(evaluate(o.left_expr, scope), o, scope)
      right = box_numeric(evaluate(o.right_expr, scope), o, scope)
      begin
        result = left.send(o.operator, right)
      rescue NoMethodError => e
        fail("Operator #{o.operator} not applicable to a value of type #{left.class}", o, scope)
      end
#      puts "Arithmetic returns '#{left}' #{o.operator} '#{right}' => #{result}"
#      puts "left = #{o.left_expr.class}, #{o.left_expr.value}"
#      puts "right = #{o.right_expr.class}, #{o.right_expr.value}"
      result
    end
    
    # Evaluates Puppet DSL ->, ~>, <-, and <~
    def eval_RelationshipExpression(o, scope)
      real = eval_BinaryExpression(o, scope)
      
      # assert operator (should have been validated, but this logic makes assumptions which would
      # screw things up royally). Better safe than sorry.
      unless [:'->', :'~>', :'<-', :'<~'].include?(o.operator)
        fail "Unknown operator #{o.operator}.", o, scope
      end
  
      # assert they are all CatalogResource objects
      real.flatten.each do |r| 
        unless r.is_a?(CatalogResource)
          fail "A relationship can only be established between resources. Got an instance of #{r.class}.", o, scope
        end
      end
  
      # reverse order if operator is Right to Left
      adjusted = if [:'<-', :'<~'].include?(o.operator)
        real.reverse
      else
        real
      end
      
      # is this a subscription or order/dependency
      method = if [:'<~', '~>'].include?(o.operator)
        :'addSubscribers'
      else
        :'addFollowers'
      end
      
      # make associations
      adjusted.product.each {|from, to| from.send(method, to) }
        
      # result is the evaluated right expression (irrespective of the operator's direction)
      # Example: File[foo] -> File[bar]  => File[bar]
      real.slice(1)
    end
    
    # Evaluates x[key]
    #
    def eval_AccessExpression(o, scope)
      left = evaluate(o.left_expr, scope)
      container = if o.left_expr.is_a?(Puppet::Pops::API::Model::QualifiedName)
        begin
          scope.get_data_entry(left.value, right)
        rescue NoSuchPuppetType
          fail "Unknown or illegal type name #{left}.", o, scope
        end
      else
        left
      end
      unless container.respond_to?(:'[]')
        fail "The operator [] is not applicable to the left expression.", o, scope
      end  
      # Result is the looked up key
      case o.keys.size
      when 0
        nil # or issue error
      when 1
        # single value result
        container[evaluate(o.keys()[0], scope)]
      else
        # multiple keys, result is an array
        o.keys.collect {|k| container[evaluate(k, scope)] }
      end
    end
    
    # Evaluates <, <=, >, >=, and ==
    # 
    def eval_ComparisonExpression o, scope
      left, right = eval_BinaryExpression o, scope
      
      begin
        case o.operator
        when :'=='
          @compare_operator.equals(left,right)
        when :'!=' 
          ! @compare_operator.equals(left,right)
        when :'<'
          @compare_operator.compare(left,right) < 0
        when :'<='
          @compare_operator.compare(left,right) <= 0
        when :'>'
          @compare_operator.compare(left,right) > 0
        when :'>='
          @compare_operator.compare(left,right) >= 0
        else
          fail("Internal Error: unhandled comparison operator '#{o.operator}'.", o, scope)
        end
      rescue ArgumentError => e
        fail("Comparison of #{left.class} #{o.operator} #{right.class} is not possible. Caused by #{e.message}.", o, scope)
      end
    end
  
    # Evaluates matching expressions with string or regexp rhs expression.
    #
    # @example
    #   x =~ /abc.*/
    # @example
    #   x =~ "abc.*/"
    # @example
    #   y = "abc"
    #   x =~ "${y}.*"
    # @return [Boolean] if a match was made or not. Also sets $0..$n to matchdata in current scope.
    #
    def eval_MatchExpression o, scope
      left, pattern = eval_BinaryExpression o, scope
      begin
       pattern = Regexp.new(pattern) unless pattern.is_a?(Regexp)  
      rescue StandardError => e
        fail "Can not convert right expression to a regular expression. Caused by: '#{e.message}'", o, scope 
      end
      # DEBUGGING
      # puts "matching #{left} #{o.operator} #{pattern}"
      matched = pattern.match(left) # nil, or MatchData
      scope.set_match_data(matched) # creates or clears ephemeral
      
      # convert to boolean true, or false
      o.operator == :'=~' ? !!matched : !matched
    end
    
    # Evaluates Puppet DSL `in` expression
    # @todo Puppet only allows in where left is a String, since this evaluator makes a distinction between
    #   Numeric and String, this is relaxed, (Currently there is no check and ´in´ just searches for lhs
    #   in rhs where rhs must respond to :include? (Hashes, String and Arrays).
    #
    def eval_InExpression o, scope
      left, right = eval_BinaryExpression o, scope

      # Unwanted restriction
      # TODO: make this controlled by preference
      #      unless left.is_a?(::String)
      #        fail("'#{left}' from left operand of 'in' expression is not a string", o, scope)
      #      end
      unless right.respond_to?(:include?)
        fail("'#{right}' from right operand of 'in' expression is not of a supported type (string, array or hash)")
      end
      right.include?(left)
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
    def eval_CaseExpression o, scope
      test = evaluate(o.test, scope)
      result = nil
      the_default = nil
      if o.options.find do |co| 
        # the first case option that matches
        if co.values.find do |c|
              the_default = co.then_expr if c.is_a? Puppet::Pops::API::Model::LiteralDefault 
              is_match?(test, evaluate(c, scope), scope)
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
    
    # @todo not implemented - maybe not needed; this is an abstract class
    def eval_QueryExpression o, scope
      # TODO: or remove - this is the abstract query
    end
    
    # @todo not implemented
    def eval_ExportedQuery o, scope
      # TODO
    end

    # @todo not implemented
    def eval_VirtualQuery o, scope
      # TODO
    end

    # @todo not implemented
    def eval_AttributeOperation o, scope
      # TODO
    end

    # @todo not implemented
    def eval_OptionalAttributeOperation o, scope
      # TODO
    end

    # @todo not implemented
    def eval_CollectExpression o, scope
      # TODO
    end

    # @todo not implemented
    def eval_Parameter o, scope
      # TODO
    end
    
    # TODO:
    # Definition < Expression (abstract)
    # NamedDefinition < Definition (abstract)
    # ResourceTypeDefinition < NamedDefinition
    
    # NodeDefinition < Expression
    # HostClassDefinition < NamedDefinition
    # CallExpression < Expression
    # CallNamedFunctionExpression < CallExpression
    # TypeReference < Expression
    # InstanceReferences < TypeReference
    # ResourceExpression < Expression
    #    class ResourceBody < ASTObject
    # ResourceDefaultsExpression < Expression
    # ResourceOverrideExpression < Expression
    # NamedAccessExpression < Expression
  
  
    # @example
    #   $x ? { 10 => true, 20 => false, default => 0 }
    #
    def eval_SelectorExpression o, scope
      test = evaluate(o.left_expr, scope)
      selected = o.selectors.find {|s| 
        evaluate(s.matching_expr, scope) {|candidate|
          candidate == :default || is_match?(test, candidate, scope)
        }
      }
      if selected
        evaluate(selected.value_expr, scope)
      else
        nil
      end
    end
    
    # Evaluates Puppet DSL `if`
    def eval_IfExpression o, scope
      if is_true?(evaluate(o.test, scope))
        evaluate(o.then_expr, scope)
      else
        evaluate(o.else_expr, scope)
      end
    end

    # Evaluates Puppet DSL `unless`
    def eval_UnlessExpression o, scope
      unless is_true?(evaluate(o.test, scope))
        evaluate(o.then_expr, scope)
      else
        evaluate(o.else_expr, scope)
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
        fail "Internal error: a variable name should result in a String when evaluated. Got expression of #{o.expr.class} type.", o, scope
      end
      # TODO: Check for valid variable name
      if entry = scope.get_variable_entry(name)
        entry.value
      else
        # TODO: semantics of undefined variable in scope, this just returns what scope does == value or nil
        nil
      end
    end
    
    # Evaluates double quoted strings that may contain interpolation
    #
    def eval_ConcatenatedString o, scope
      o.segments.collect {|expr| evaluate(expr, scope).to_s}.join
    end
      
    # Create a metadata object that describes an attribute (an ECore EAttribute).
    # Only free-standing metadata is created to the actual attribute in a class (that happens later)
    #
    # Part of type creation. 
    #
    # @todo possibly support:
    #   changeable: false (i.e. constants)
    #   volatile: non having storage allocated (default for derived), if true = some kind of cache
    #   transient: not serialized
    #   unsettable: how the value can be reset (to default, or unset state)
    #
    def eval_CreateAttributeExpression o, scope
      # Note: Only some of the validation required takes place here
      # There are additional nonsensical invariants; like derived attributes with default values
      the_attr = RGen::ECore::EAttribute.new
      
      evaluator.fail("An attribute name must be a String", o, scope) unless o.name.is_a? String 
      the_attr.name = o.name
      
      datatype = datatype_reference(evaluate(o.type, scope), o.name, scope)
      evaluator.fail("Invalid data-type expression.", o.type, scope) unless datatype
      the_attr.eType = datatype
      
      min = evaluate(o.min_expr, scope)
      max = evaluate(o.max_expr, scope)
      min = 0 if !min || min < 0
      max = (min == 0 ? 1 : min) unless max
      max = -1 if max == 'unlimited' || max == 'many' || max == '*' || max == 'M'
      max = -1 if max < -1
      if max >= 0 && min > max
          fail("The max occurrence of an attribute must be bigger than the min occurrence (or be unlimited).", o.max_expr, scope) 
      end
      if(min == 0 && max == 0)
        fail("The min and max occurrences of an attribute can not both be 0.", o.max_expr, scope)
      end
      the_attr.lowerBound = min
      the_attr.upperBound = max
      
      # derived?
      the_attr.derived = true if o.derived_expr
      
      # TODO: possibly support:
      # changeable: false (i.e. constants)
      # volatile: non having storage allocated (default for derived), if true = cache
      # transient: not serialized
      # unsettable: how the value can be reset (to default, or unset state)
      #
      the_attr
    end

    # Creates a metadata object describing an Enumerator (An Ecore EEnum)
    # This only creates the free standing metadata. It is later used when creating a type.
    #
    def eval_CreateEnumExpression o, scope
      e_enum = RGen::ECore::EEnum.new
      e_enum.name = o.name
      values = evaluate(o.values, scope)
      case values
      when Array
        # Convert entries, the numerical representation is based on order
        values.each_index do |i|
          e_literal = RGen::ECore::EEnumLiteral.new
          e_literal.literal = values.slice(i).to_s
          e_literal.value = i
          e_literal.eEnum = e_enum
        end
      when Hash
        begin
          # Convert entries, the numerical representation is based on mapping name to value
          values.each do |k,v|
            e_literal = RGen::ECore::EEnumLiteral.new
            e_literal.literal = k.to_s
            e_literal.value = v.to_i
            e_literal.eEnum = e_enum
          end
        rescue StandardError => e
          fail("The given hash could not be converted to Enum entries. Error: "+e.message, o, scope)
        end
      else
        fail("An enumerator accepts an Array of String values, or a Hash of String to Integer mappings. Got instance of #{values.class}.", o, scope)
      end
    end

    # Creates a type, and returns a Class implementing this type
    # @todo this implementation uses scope to create the type; should use the type creator associated
    #   with the logic that wants to create a type.
    #
    def eval_CreateTypeExpression(o, scope)
      # The actual type creator is kept in the top scope (it keeps all created types)
      # The type_creator calls back to this evaluator to evaluate attributes and enums
      # it then creates both the model and a class implementation.
      scope.top_scope.type_creator.create_type(o, scope, self)
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
      if o.expr.is_a?(Puppet::Pops::API::Model::QualifiedName)
        # TODO: formalize, when scope returns nil, vs error
        result = scope.get_variable_entry(o.expr.value) 
        (result ? result.value : nil).to_s
      else
        evaluate(o.expr, scope).to_s
      end
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
    # @note to concatenate an Array, nest the array - i.e. `[1,2], [[2,3]]`
    #
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
      case x 
      when Array
        y = case y
        when Array then y
        when Hash  then y.to_a
        else
          [] << y
        end
        x + y # new array with concatenation
      when Hash
        y = case y
        when Hash then y
        when Array then Hash[*y]
        else
          raise ArgumentError.new("Can only append Array or Hash to a Hash")
        end
        x.merge y # new hash with overwrite
      else
        raise ArgumentError.new("Can only append to an Array or a Hash.")
      end
    end
  
    # Box value _v_ to numeric or fails.
    # The given value `v` is converted to Numeric, and if that fails the operation
    # calls {#fail}.
    # @param v [Object] the value to convert
    # @param o [Object] originating instruction
    # @param scope [Puppet::Pops::API::Scope] the scope where evaluation of o takes place
    # @return [Numeric] value `v` converted to Numeric.
    #
    def box_numeric v, o, scope
      unless n = Puppet::Pops::API::Utils.to_n(v)
        fail "Value '#{v}' can not be converted to Numeric.", o, scope
      end
      n
    end
    
    # Raises evaluation error with a composed message.
    # An exception is raised with a message composed out of the given `message` and information
    # obtained from the given _originating object_ `o`.
    # @return [!] this method does nmot return
    # @raise [Puppet::Pops::EvaluationError
    #
    def fail message, o, scope
      # TODO: fail evaluation with message, failure evaluating o, in scope
      # TODO: This just fails with the message, should include a label for the expression
      #       and any origin set in an adapter for o. Scope could be passed for debugging
      #       purposes / stackdump
      raise Puppet::Pops::EvaluationError.new(message)
    end
    
    # Implementation of case option matching.
    #
    # This is the type of matching performed in a case option, using == for every type
    # of value except regular expression where a match is performed.
    # @todo there are implementation issues left to deal with (see source)
    #
    def is_match? left, right, scope
      # TODO: deal with TypeError
      # TODO: match when left is a Number, or something strange
      # TODO: solution should be used in MatchExpression
      if right.is_a?(Regexp)
        matched = right.match(left)
        scope.set_match_data(matched)
        !!matched
      else
        left == right
      end
    end
  
    # This is the same type of "truth" as used in the current Puppet DSL.
    #
    def is_true? o
      # Is the value true?  This allows us to control the definition of truth
      # in one place.
      case o
      when ''
        false
      when :undef
        false
      else
        !!o
      end
    end
    
    # Utility method for TrueClass || FalseClass
    # @param x [Object] the object to test if it is instance of TrueClass or FalseClass
    def is_boolean? x
      x.is_a?(TrueClass) || x.is_a?(FalseClass)
    end
  
  
    # Translates data type name to instance of a data type.
    #
    # Maps an object to an instance of RGen::ECore::EDataType - i.e. returns
    # an enum, `EString`, `EInt`, `EFloat`, or `EBoolean`. The default (if nil) is `EString`.
    # If an instance of EEnum is passed, a new Enum datatype is created named after the 
    # attributes (e.g. fooEnumValues) unless the enum is already named. This named enum can not
    # be accessed and reused, but it is of value when debugging that it has a name related to
    # the attribute).
    # 
    # @param o [String, RGen::Ecore::EDataType, nil] reference to, or real data type
    # @param attribute_name [String] the name of the attribute having data type given by `o`
    # @param scope [Puppet::Pops::API::Scope] the scope where this instruction is evaluated
    # @return [RGen::ECore::EDataType] a datatype for `o` with name `attribute_name`, being one of
    #   a named enum, `EString`, `EInt`, `EFloat`, or `EBoolean`. The default (if nil) is `EString`.
    #
    # @todo the scope should not be part of the signature; it is currently used to get to a type creator where
    #   an enum can be created. It should instead use an adapter to find the type creator associated
    #   with the actual object (i.e. create the datatype in the same package as it's container).
    #   This is not known by the scope.
    #
    def datatype_reference(o, attribute_name, scope)
      case o
      when RGen::ECore::EEnum
        o.ePackage = package
        # anonymous enums are named after the attribute
        # This is slightly problematic as the names are stored as constants in the 
        # module, and may thus overwrite a constant (which does not really matter) since
        # the constant gets erased anyway by the type creator
        # after having been associated with the created object/class.
        # 
        o.name = attribute_name + "EnumValues" unless o.name
        scope.top_scope.type_creator.create_enum o
      when RGen::ECore::EDataType
        # Already resolved to a data type
        o  
      when 'String'
        RGen::ECore::EString
      when 'Integer'
        RGen::ECore::EInt
      when 'Float' 
        RGen::ECore::EFloat
      when 'Boolean'
        RGen::ECore::EBoolean
      when NilClass
        # Default, if no expression given
        RGen::ECore::EString
      else
        nil
      end  
    end        
end; end; end;end;