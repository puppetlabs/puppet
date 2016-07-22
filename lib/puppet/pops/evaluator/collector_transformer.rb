module Puppet::Pops
module Evaluator
class CollectorTransformer

  def initialize
    @@query_visitor    ||= Visitor.new(nil, "query", 1, 1)
    @@match_visitor    ||= Visitor.new(nil, "match", 1, 1)
    @@evaluator        ||= EvaluatorImpl.new
    @@compare_operator ||= CompareOperator.new()
  end

  def transform(o, scope)
    raise ArgumentError, "Expected CollectExpression" unless o.is_a? Model::CollectExpression

    raise "LHS is not a type" unless o.type_expr.is_a? Model::QualifiedReference
    type = o.type_expr.value().downcase()

    if type == 'class'
      fail "Classes cannot be collected"
    end

    resource_type = Runtime3ResourceSupport.find_resource_type(scope, type)

    fail "Resource type #{type} doesn't exist" unless resource_type

    adapter = Adapters::SourcePosAdapter.adapt(o)
    line_num = adapter.line
    position = adapter.pos
    file_path = adapter.locator.file

    if !o.operations.empty?
      overrides = {
        :parameters => o.operations.map{ |x| @@evaluator.evaluate(x, scope)}.flatten,
        :file       => file_path,
        :line       => [line_num, position],
        :source     => scope.source,
        :scope      => scope
      }
    end

    code = query_unless_nop(o.query, scope)

    case o.query
    when Model::VirtualQuery
      newcoll = Collectors::CatalogCollector.new(scope, resource_type.name, code, overrides)
    when Model::ExportedQuery
      match = match_unless_nop(o.query, scope)
      newcoll = Collectors::ExportedCollector.new(scope, resource_type.name, match, code, overrides)
    end

    scope.compiler.add_collection(newcoll)

    newcoll
  end

protected

  def query(o, scope)
    @@query_visitor.visit_this_1(self, o, scope)
  end

  def match(o, scope)
    @@match_visitor.visit_this_1(self, o, scope)
  end

  def query_unless_nop(query, scope)
    unless query.expr.nil? || query.expr.is_a?(Model::Nop)
      query(query.expr, scope)
    end
  end

  def match_unless_nop(query, scope)
    unless query.expr.nil? || query.expr.is_a?(Model::Nop)
      match(query.expr, scope)
    end
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

    case o.operator
    when :'=='
      if left_code == "tag"
        # Ensure that to_s and downcase is done once, i.e. outside the proc block and
        # then use raw_tagged? instead of tagged?
        if right_code.is_a?(Array)
          tags = right_code
        else
          tags = [ right_code ]
        end
        tags = tags.collect do |t|
          raise ArgumentError, 'Cannot transform a number to a tag' if t.is_a?(Numeric)
          t.to_s.downcase
        end
        proc do |resource|
          resource.raw_tagged?(tags)
        end
      else
        proc do |resource|
          if (tmp = resource[left_code]).is_a?(Array)
            @@compare_operator.include?(tmp, right_code, scope)
          else
            @@compare_operator.equals(tmp, right_code)
          end
        end
      end
    when :'!='
      proc do |resource|
        !@@compare_operator.equals(resource[left_code], right_code)
      end
    end
  end

 def query_AccessExpression(o, scope)
    pops_object = @@evaluator.evaluate(o, scope)

    # Convert to Puppet 3 style objects since that is how they are represented
    # in the catalog.
    @@evaluator.convert(pops_object, scope, nil)
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

  def query_ConcatenatedString(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_LiteralNumber(o, scope)
    @@evaluator.evaluate(o, scope)
  end

  def query_LiteralUndef(o, scope)
    nil
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

  def match_AccessExpression(o, scope)
    pops_object = @@evaluator.evaluate(o, scope)

    # Convert to Puppet 3 style objects since that is how they are represented
    # in the catalog.
    @@evaluator.convert(pops_object, scope, nil)
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

  def match_LiteralUndef(o, scope)
    nil
  end

  def match_ConcatenatedString(o, scope)
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
end
end
end
