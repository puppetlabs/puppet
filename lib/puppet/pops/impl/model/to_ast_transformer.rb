require 'puppet/pops/api/model/model'
require 'puppet/pops/api/visitor'
require 'puppet/parser/ast'

module Puppet; module Pops; module Impl; module Model

  # Transforms a Pops::Model to classic Puppet AST.
  # TODO: Location not handled yet
  # TODO: Documentation is currently skipped completely (it is only used for Rdoc)
  #
  class ToAstTransformer
    
    def initialize
      @transform_visitor = Puppet::Pops::API::Visitor.new(self,"transform",0,0)
      @query_transform_visitor = Puppet::Pops::API::Visitor.new(self,"query",0,0)
      @hostname_transform_visitor = Puppet::Pops::API::Visitor.new(self,"hostname",0,0)
    end
     
    # Initialize klass from o and hash    
    def ast klass, o, hash 
      # TODO: Pick up generic file and line from o
      klass.new hash
    end
    
    # Transforms pops expressions into AST 3.1 statements/expressions
    def transform(o)
      @transform_visitor.visit(o)
    end
    
    # Transforms pops expressions into AST 3.1 query expressions
    def query(o)
      @query_transform_visitor.visit(o)
    end

    # Transforms pops expressions into AST 3.1 hostnames
    def hostname(o)
      @hostname_transform_visitor.visit(o)
    end
    
    def transform_LiteralNumber o
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
      
      # Numbers are strings in the AST
      ast AST::String, :value => s
    end
    
    # Transforms all literal values to string (override for those that should not be AST::String)
    #
    def transform_LiteralValue o
      ast AST::String, :value => o.value.to_s
    end
    
    def transform_Factory o
      transform(o.current)
    end

    def transform_ArithmeticExpression o
      ast AST::ArithmeticOperator, :lval => transform(o.left_expr), :rval=>transform(o.right_expr), :operator => o.operator
    end
    
    def transform_Array o
      ast AST::ASTArray, :children => o.collect {|x| transform(x) }
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
    def transform_AccessExpression o
      case o.left_expr
      when Puppet::Pops::API::Model::QualifiedName
        ast AST::ResourceReference, :type => o.left_expr.value, :title => transform(o.keys)
        
      when Puppet::Pops::API::Model::QualifiedReference
        ast AST::ResourceReference, :type => o.left_expr.value, :title => transform(o.keys)
        
      when Puppet::Pops::API::Model::VariableExpression
        ast AST::HashOrArrayAccess, :variable => o.expr.value(), :key => transform(o.keys()[0])
        
      when Puppet::Pops::API::Model::AccessExpression
        ast AST::HashOrArrayAccess, :variable => transform(o.left_expr), :key => transform(o.keys()[0])
      end
    end

    def transform_MatchesExpression o
      ast AST::MatchOperator, :lval => transform(o.left_expr), :rval=>transform(o.right_expr), :operator => o.operator
    end

    # Puppet AST has a complicated structure
    # LHS can not be an expression, it must be a type (which is downcased).
    # type = a downcased QualifiedName
    # 
    def transform_CollectExpression o
      raise "LHS is not a type" unless o.type_expr.is_a? Puppet::Pops::API::Model::QualifiedReference
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
      ast AST::Collection, args
    end

    def transform_ExportedQuery o
      if is_nop?(o.expr)
        result = :exported
      else
        result = query(o.expr)
        result.form = :exported
      end
      result
    end

    def transform_VirtualQuery o
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
    def query_Object o
      raise "Not a valid expression in a collection query"
    end
    
    # Puppet AST only allows == and !=
    #
    def query_ComparisonExpression o
      if [:'==', :'!='].contains o.operator
        ast AST::CollExpr, :test1 => query(o.left_expr), :oper => o.operator, :test2 => query(o.right_expr)
      else
        raise "Not a valid comparison operator in a collection query: " + o.operator.to_s
      end
    end
    def query_AndExpression o
      ast AST::CollExpr, :test1 => query(o.left_expr), :oper => :'and', :test2 => query(o.right_expr)
    end
    
    def query_OrExpression o
      ast AST::CollExpr, :test1 => query(o.left_expr), :oper => :'or', :test2 => query(o.right_expr)
    end

    def query_ParenthesizedExpression o
      result = query(o.expr) # produces CollExpr
      result.parens = true
      result
    end
    
    def query_VariableExpression o
      transform(o)
    end
    
    def query_QualifiedName o
      transform(o)
    end
    
    def query_LiteralNumber o
      transform(o) # number to string in correct radix
    end
    
    def transform_QualifiedName o
      ast AST::Name, :value => o.value
    end
    
    def transform_QualifiedReference o
      ast AST::Type, :value => o.value
    end
    
    def transform_ComparisonExpression o
      ast AST::ComparisonOperator, :operator => o.operator, :lval => transform(o.left_expr), :rval => transform(o.right_expr)       
    end
    
    def transform_AndExpression o
      ast AST::BooleanOperator, :operator => :'and', :lval => transform(o.left_expr), :rval => transform(o.right_expr)
    end
    
    def transform_OrExpression o       
      ast AST::BooleanOperator, :operator => :'or', :lval => transform(o.left_expr), :rval => transform(o.right_expr)
    end
    
    def transform_InExpression o
      ast AST::InOperator, :lval => transform(o.left_expr), :rval => transform(o.right_expr)
    end
 
    def transform_InstanceReferences o
      ast AST::ResourceReference, :type => o.type_name.value, :title => transform(o.names)
    end

    # Assignment in AST 3.1 is to variable or hasharray accesses !!! See Bug #16116
    def transform_AssignmentExpression o
      args = {:value => transform(o.right_expr) }
      args[:appends] = true if o.operator == :'+='
      
      args[:name] = case o.left_expr
      when Puppet::Pops::API::Model::VariableExpression
        o.left_expr.expr.value
      when Puppet::Pops::API::Model::AccessExpression
        transform(o.left_expr)
      else
        raise "LHS is not an expression that can be assigned to"
      end    
      ast AST::VarDef, args
    end

    # Produces (name => expr) or (name +> expr)
    def transform_AttributeOperation o
      args = { :value => transform(o.value_expr) }
      args[:add] = true if o.operator == :'+>'
      args[:param] = o.attribute_name  
      ast AST::ResourceParam, args
    end

    def transform_LiteralList o
      # Uses default transform of Ruby Array to ASTArray
      transform(o.values)
    end
    
    # Literal hash has strange behavior in Puppet 3.1. See Bug #19426, and this implementation is bug
    # compatible
    def transform_LiteralHash o
      if o.entries.size == 0
        ast AST::AstHash, :value=> {}
      else
        value = {}
        o.entries.each {|x| value.merge transform(x) }
        ast AST::AstHash, :value=> value
      end
    end
    
    # Transforms entry into a hash (they are later merged with strange effects: Bug #19426).
    # Puppet 3.x only allows:
    # * NAME
    # * quotedtext
    # As keys (quoted text can be an interpolated string which is compared as a key in a less than satisfactory way).
    #
    def transform_KeyedEntry o
      value = transform(o.value)
      key = case o.key
      when Puppet::Pops::API::Model::QualifiedName
        o.key.value
      when Puppet::Pops::API::Model::LiteralString
        transform o.key
      when Puppet::Pops::API::Model::ConcatentatedString
        transform o.key
      else
        raise "Illegal hash key expression"
      end
      
      {key => value}       
    end
    
    def transform_MatchExpression o
      ast AST::MatchOperator, :operator => o.operator, :lval => transform(o.left_expr), :rval => transform(o.right_expr)
    end
    
    def transform_LiteralString o
      ast AST::String, :value => o.value
    end
    
    # Literal text in a concatenated string
    def transform_LiteralText o
      ast AST::String, :value => o.value
    end

    def transform_LambdaExpression o
      ast AST::Lambda, 
              :parameters => o.parameters.collect {|p| transform(p) },
              :children => transform(o.body)
    end
    
    def transform_LiteralDefault o
      ast AST::Default, :value => :default
    end

    def transform_LiteralUndef o
      ast AST::Undef, :value => :undef
    end

    def transform_LiteralRegularExpression o
      ast AST::Regex, :value => o.value
    end
    
    def transform_Nop o
      ast AST::Nop
    end
 
    # In the 3.1. grammar this is a hash that is merged with other elements to form a method call
    # Also in 3.1. grammar there are restrictions on the LHS (that are only there for grammar issues).
    #   
    def transform_NamedAccessExpression o
      [".", do_dump(o.left_expr), do_dump(o.right_expr)]
      receiver = transform(o.left_expr)
      name = o.right_expr
      raise "Unacceptable function/method name" unless name.is_a? Puppet::Pops::API::Model::QualifiedName
      {:receiver => receiver, :name => name.value}
    end

    def transform_NilClass o
      ast AST::Nop
    end
    
    def transform_NotExpression o
      ast AST::Not, :value => transform(o.expr)
    end
    
    def transform_VariableExpression o
      # assumes the expression is a QualifiedName
      ast AST::Variable, :value => o.expr.value
    end
    
    # In Puppet 3.1, the ConcatenatedString is responsible for the evaluation and stringification of
    # expression segments. Expressions and Strings are kept in an array.
    def transform_TextExpression o
      transform(o.expr)
    end
    
    def transform_UnaryMinusExpression o
      ast AST::Minus, :value => transform(o.expr)
    end

    # Puppet 3.1 representation of a BlockExpression is an AST::Array - this makes it impossible to differentiate
    # between a LiteralArray and a Sequence. (Should it return the collected array, or the last expression?)
    #
    def transform_BlockExpression o
      ["block"] + o.statements.collect {|x| do_dump(x) }
    end
    
    # Interpolated strings are kept in an array of AST (string or other expression).
    def transform_ConcatenatedString o
      ast AST::Concat, :value => o.segments.collect {|x| transform(x)} 
    end
        
    def transform_HostClassDefinition o
      Puppet::Parser::AST::Hostclass.new(o.name,
        :arguments => transform(o.parameters), 
          :parent => o.parent_class, 
          :code => transform(o.body) 
          )
      # TODO: since ast function is not used, the result must receive its LOCATION
      #    
    end

    def transform_NodeDefinition o
      # o.host_matches are expressions, and 3.1 AST requires special object AST::HostName
      # where a HostName is one of NAME, STRING, DEFAULT or Regexp - all of these are strings except regexp
      #
      Puppet::Parser::AST::Node.new(hostname(o.host_matches),
        :parent => transform(o.parent), 
        :code => transform(o.body)
        )
      # TODO: since ast function is not used, the result must receive its location
      #    
    end

    # Transforms Array of host matching expressions into a (Ruby) array of AST::HostName
    def hostname_Array o
      o.collect {|x| ast AST::HostName, :value => hostname(x) }
    end
    
    def hostname_LiteralValue o
      return o.value
    end

    def hostname_QualifiedName o
      return o.value
    end
    
    def hostname_LiteralNumber o
      transform(o) # Number to string with correct radix
    end

    def hostname_LiteralDefault o
      return 'default'
    end

    def hostname_LiteralRegexp o
      return o.value
    end

    def hostname_Object o
      raise "Illegal expression - unacceptable as a node name"
    end

    def transform_ResourceTypeDefinition o
      Puppet::Parser::AST::Definition.new(o.name,
        :arguments => transform(o.parameters), 
          :code => transform(o.body) 
          )
      # TODO: since ast function is not used, the result must receive its location
      #    
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
    def transform_ResourceOverrideExpression o
      resource_ref = o.resources
      raise "Unacceptable expression for resource override" unless resource_ref.is_a? Puppet::Pops::API::Model::AccessExpression
      
      type = case resource_ref.left_expr
      when Puppet::Pops::API::Model::QualifiedName
        # This is deprecated "Resource references should now be capitalized" - this is caught elsewhere
        resource_ref.left_expr.value
      when Puppet::Pops::API::Model::QualifiedReference
        resource_ref.left_expr.value
      else
        raise "Unacceptable expression for resource override; need NAME or CLASSREF"
      end
      
      result_ref = ast AST::ResourceReference, :type => type, :title => transform(resource_ref.keys)
      
      # title is one or more expressions, if more than one it should be an ASTArray  
      ast AST::ResourceOverride, :object => result_ref, :parameters => transform(o.operations)        
    end

    # Parameter is a parameter in a definition of some kind. 
    # It is transformed to an array on the form `[name]´, or `[name, value]´. 
    def transform_Parameter o
      if o.value
        [o.name, transform(o.value)]
      else
        [o.name]
      end
    end
    
    # For non query expressions, parentheses can be dropped in the resulting AST.
    def transform_ParenthesizedExpression o
      transform(o.expr)
    end
    
    def transform_IfExpression o
      args = { :test => transform(o.test), :statements => transform(o.then_expr) }
      args[:else] = transform(o.else_expr) unless is_nop? o.else_expr      
      result = ast AST::IfStatement, args
    end
    
    # Unless is not an AST object, instead an AST::IfStatement is used with an AST::Not around the test
    #
    def transform_UnlessExpression o
      args = { :test => ast(AST::Not, :value => transform(o.test)), 
        :statements => transform(o.then_expr) }
      # AST 3.1 does not allow else on unless
      raise "Unsupported syntax, unless can not have an else clause" unless is_nop?(o.else_expr)
      result = ast AST::IfStatement, args
    end

    # Pupept 3.1 AST only supports calling a function by name (it is not possible to produce a function
    # that is then called).
    # rval_required (for an expression)
    # functor_expr (lhs - the "name" expression)
    # arguments - list of arguments
    #
    def transform_CallNamedFunctionExpression o
      name = o.functor_expr
      raise "Unacceptable expression for name of function" unless name.is_a? Puppet::Pops::API::Model::QualifiedName
      ast AST::Function,
          :name => name.value,
          :arguments => transform(o.arguments),
          :ftype => o.rval_required ? :rvalue : :statement          
    end

    # Transformation of CallMethodExpression handles a NamedAccessExpression functor and
    # turns this into a 3.1 AST::MethodCall.
    #
    def transform_CallMethodExpression o
      name = o.functor_expr
      raise "Unacceptable expression for name of function" unless name.is_a? Puppet::Pops::API::Model::NamedAccessExpression
      # transform of NamedAccess produces a hash, add arguments to it
      ast AST::MethodCall, transform(name).merge(:arguments => transform(o.arguments))          

    end

    def transform_CaseExpression o
      # Expects expression, AST::ASTArray of AST
      ast AST::CaseStatement, :test => transform(o.test), :options => transform(o.options)
    end
    
    def transform_CaseOption o
      ast AST::CaseOpt, :value => transform(o.values), :statements => transform(o.then_expr)
    end
    
    def transform_ResourceBody o
      # expects AST, AST::ASTArray of AST
      ast AST::ResourceInstance, :title => transform(o.title), :parameters => transform(o.operations)
    end

    def transform_ResourceDefaultsExpression o
      ast AST::ResourceDefaults, :type => o.type_ref.value, :parameters => transform(o.operations)
    end

    # Transformation of ResourceExpression requires calling a method on the resulting
    # AST::Resource if it is virtual or exported
    #
    def transform_ResourceExpression o
      raise "Unacceptable type name expression" unless o.type_name.is_a? Puppet::Pops::API::QualifiedName  
      resource = ast AST::Resource, :type => o.type_name.value, :instances => transform(o.bodies)
      resource.send("#{form}=", true) unless form == :regular
      resource
    end

    # Transformation of SelectorExpression is limited to certain types of expressions.
    # This is probably due to constraints in the old grammar rather than any real concerns.
    def transform_SelectorExpression o
      case o.left_expr
      when Puppet::Pops::API::Model::CallNamedFunction
      when Puppet::Pops::API::Model::AccessExpression
      when Puppet::Pops::API::Model::VariableExpression
      when Puppet::Pops::API::Model::ConcatenatedString
      else
        raise "Unacceptable select expression" unless o.left_expr.kind_of? Puppet::Pops::Model::API::Literal
      end
      ast AST::Selector, :param => transform(o.left_expr), :values => transform(o.selectors)
    end

    def transform_SelectorEntry o
      ast AST::ResourceParam, :param => transform(o.matching_expr), :value => transform(o.value_expr)
    end
    
    def transform_Object o
      raise "Unacceptable transform - found an Object without a rule."
    end
    
    # Nil, nop
    # Bee bopp a luh-lah, a bop bop boom.
    #    
    def is_nop? o
      o.nil? || o.is_a?(Puppet::Pops::API::Model::Nop)
    end
  end
end; end; end; end