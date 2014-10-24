class Puppet::Pops::Evaluator::CollectorTransformer

  def initialize
    @@query_visitor    ||= Puppet::Pops::Visitor.new(nil, "query", 1, 1)
    @@match_visitor    ||= Puppet::Pops::Visitor.new(nil, "match", 1, 1)
    @@evaluator        ||= Puppet::Pops::Evaluator::EvaluatorImpl.new
    @@compare_operator ||= Puppet::Pops::Evaluator::CompareOperator.new()
  end

  def query(o, scope)
    @@query_visitor.visit_this(self, o, scope)
  end

  def match(o, scope)
    @@match_visitor.visit_this(self, o, scope)
  end

  def transform(o, scope)
    raise ArgumentError, "Expected CollectExpression" unless o.is_a? Puppet::Pops::Model::CollectExpression

    raise "LHS is not a type" unless o.type_expr.is_a? Puppet::Pops::Model::QualifiedReference
    type = o.type_expr.value().downcase()
    args = { :type => type }

    if type == 'class'
      fail "Classes cannot be collected"
    end

    resource_type = scope.find_resource_type(type)
    fail "Resource type #{type} doesn't exist" unless resource_type

    form =
      case o.query
      when Puppet::Pops::Model::VirtualQuery
        :virtual
      when Puppet::Pops::Model::ExportedQuery
        :exported
      end

    if o.query.expr.nil? || o.query.expr.is_a?(Puppet::Pops::Model::Nop)
      code = nil
      match = nil
    else
      code = query(o.query.expr, scope)
      match = match(o.query.expr, scope)
    end

    newcoll = Puppet::Parser::Collector.new(scope, resource_type.name, match, code, form)
    scope.compiler.add_collection(newcoll)

    adapter = Puppet::Pops::Adapters::SourcePosAdapter.adapt(o)
    line_num = adapter.line
    position = adapter.pos
    file_path = adapter.locator.file

    # overrides if any
    # Evaluate all of the specified params.
    if !o.operations.empty?
      newcoll.add_override(
        :parameters => o.operations.map{ |x| to_3x_param(x).evaluate(scope)},
        :file       => file_path,
        :line       => [line_num, position],
        :source     => scope.source,
        :scope      => scope
      )
    end

    newcoll
  end

  def query_AndExpression(o, scope)
    left_code = query(o.left_expr, scope)
    right_code = query(o.right_expr, scope)
    proc do |resource|
      left_code.call(resource) && right_code.call(resource)
    end
  end

  def query_OrExpression(o, scope)
    left_code = query(o.left_expr, scope)
    right_code = query(o.right_expr, scope)
    proc do |resource|
      left_code.call(resource) || right_code.call(resource)
    end
  end

  def query_ComparisonExpression(o, scope)
    left_code = query(o.left_expr, scope)
    right_code = query(o.right_expr, scope)

    proc do |resource|
      case o.operator
      when :'=='
        if left_code == "tag"
          resource.tagged?(right_code)
        else
          if resource[left_code].is_a?(Array)
            @@compare_operator.include?(resource[left_code], right_code, scope)
          else
            @@compare_operator.equals(resource[left_code], right_code)
          end
        end
      when :'!='
        !@@compare_operator.equals(resource[left_code], right_code)
      end
    end
  end

  def query_VariableExpression(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_LiteralBoolean(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_LiteralString(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_LiteralNumber(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_QualifiedName(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_ParenthesizedExpression(o, scope)
   query(o.expr, scope)
  end

  def query_Object(o, scope)
    raise ArgumentError, "Cannot transform object of class #{o.class}"
  end

  def match_AndExpression(o, scope)
    left_match = match(o.left_expr, scope)
    right_match = match(o.right_expr, scope)
    return [left_match, 'and', right_match]
  end

  def match_OrExpression(o, scope)
    left_match = match(o.left_expr, scope)
    right_match = match(o.right_expr, scope)
    return [left_match, 'or', right_match]
  end

  def match_ComparisonExpression(o, scope)
    left_match = match(o.left_expr, scope)
    right_match = match(o.right_expr, scope)
    return [left_match, o.operator.to_s, right_match]
  end

  def match_VariableExpression(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def match_LiteralBoolean(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def match_LiteralString(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def match_LiteralNumber(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def match_QualifiedName(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def match_ParenthesizedExpression(o, scope)
   match(o.expr, scope)
  end

  def match_Object(o, scope)
    raise ArgumentError, "Cannot transform object of class #{o.class}"
  end

  # Produces (name => expr) or (name +> expr)
  def to_3x_param(o)
    bridge = Puppet::Parser::AST::PopsBridge::Expression.new(:value => o.value_expr)
    args = { :value => bridge }
    #TODO: May delete this line later
    args[:add] = true if o.operator == :'+>'
    args[:param] = o.attribute_name
    args= Puppet::Pops::Model::AstTransformer.new().merge_location(args, o)
    Puppet::Parser::AST::ResourceParam.new(args)
  end
end
