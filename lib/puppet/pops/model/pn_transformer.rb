module Puppet::Pops
module Model


class PNTransformer
  def self.visitor
    @visitor ||= Visitor.new(nil, 'transform', 0, 0)
  end

  def self.singleton
    @singleton ||= new(visitor)
  end

  def self.transform(ast)
    singleton.transform(ast)
  end

  def initialize(visitor)
    @visitor = visitor
  end

  def transform(ast)
    @visitor.visit_this_0(self, ast)
  end

  def transform_AccessExpression(e)
    PN::List.new([transform(e.left_expr)] + pn_array(e.keys)).as_call('access')
  end

  def transform_AndExpression(e)
    binary_op(e, 'and')
  end

  def transform_Application(e)
    definition_to_pn(e, 'application')
  end

  def transform_ArithmeticExpression(e)
    binary_op(e, e.operator)
  end

  def transform_Array(a)
    PN::List.new(pn_array(a))
  end

  def transform_AssignmentExpression(e)
    binary_op(e, e.operator)
  end

  def transform_AttributeOperation(e)
    PN::Call.new(e.operator, PN::Literal.new(e.attribute_name), transform(e.value_expr))
  end

  def transform_AttributesOperation(e)
    PN::Call.new('splat-hash', transform(e.expr))
  end

  def transform_BlockExpression(e)
    transform(e.statements).as_call('block')
  end

  def transform_CallFunctionExpression(e)
    call_to_pn(e, 'call-lambda', 'invoke-lambda')
  end

  def transform_CallMethodExpression(e)
    call_to_pn(e, 'call-method', 'invoke-method')
  end

  def transform_CallNamedFunctionExpression(e)
    call_to_pn(e, 'call', 'invoke')
  end

  def transform_CapabilityMapping(e)
    PN::Call.new(e.kind, transform(e.component), PN::List.new([PN::Literal.new(e.capability)] + pn_array(e.mappings)))
  end

  def transform_CaseExpression(e)
    PN::Call.new('case', transform(e.test), transform(e.options))
  end

  def transform_CaseOption(e)
    PN::Map.new([transform(e.values).with_name('when'), block_as_entry('then', e.then_expr)])
  end

  def transform_CollectExpression(e)
    entries = [transform(e.type_expr).with_name('type'), transform(e.query).with_name('query')]
    entries << transform(e.operations).with_name('ops') unless e.operations.empty?
    PN::Map.new(entries).as_call('collect')
  end

  def transform_ComparisonExpression(e)
    binary_op(e, e.operator)
  end

  def transform_ConcatenatedString(e)
    transform(e.segments).as_call('concat')
  end

  def transform_EppExpression(e)
    e.body.nil? ? PN::Call.new('epp') : transform(e.body).as_call('epp')
  end

  def transform_ExportedQuery(e)
    is_nop?(e.expr) ? PN::Call.new('exported-query') : PN::Call.new('exported-query', transform(e.expr))
  end

  def transform_Factory(e)
    transform(e.model)
  end

  def transform_FunctionDefinition(e)
    definition_to_pn(e, 'function', nil, e.return_type)
  end

  def transform_HeredocExpression(e)
    entries = []
    entries << PN::Literal.new(e.syntax).with_name('syntax') unless e.syntax == ''
    entries << transform(e.text_expr).with_name('text')
    PN::Map.new(entries).as_call('heredoc')
  end

  def transform_HostClassDefinition(e)
    definition_to_pn(e, 'class', e.parent_class)
  end

  def transform_IfExpression(e)
    if_to_pn(e, 'if')
  end

  def transform_InExpression(e)
    binary_op(e, 'in')
  end

  def transform_KeyedEntry(e)
    PN::Call.new('=>', transform(e.key), transform(e.value))
  end

  def transform_LambdaExpression(e)
    entries = []
    entries << parameters_entry(e.parameters) unless e.parameters.empty?
    entries << transform(e.return_type).with_name('returns') unless e.return_type.nil?
    entries << block_as_entry('body', e.body) unless e.body.nil?
    PN::Map.new(entries).as_call('lambda')
  end

  def transform_LiteralBoolean(e)
    PN::Literal.new(e.value)
  end

  def transform_LiteralDefault(_)
    PN::Call.new('default')
  end

  def transform_LiteralFloat(e)
    PN::Literal.new(e.value)
  end

  def transform_LiteralHash(e)
    transform(e.entries).as_call('hash')
  end

  def transform_LiteralInteger(e)
    vl = PN::Literal.new(e.value)
    e.radix == 10 ? vl : PN::Map.new([PN::Literal.new(e.radix).with_name('radix'), vl.with_name('value')]).as_call('int')
  end

  def transform_LiteralList(e)
    transform(e.values).as_call('array')
  end

  def transform_LiteralRegularExpression(e)
    PN::Literal.new(Types::PRegexpType.regexp_to_s(e.value)).as_call('regexp')
  end

  def transform_LiteralString(e)
    PN::Literal.new(e.value)
  end

  def transform_LiteralUndef(_)
    PN::Literal.new(nil)
  end

  def transform_MatchExpression(e)
    binary_op(e, e.operator)
  end

  def transform_NamedAccessExpression(e)
    binary_op(e, '.')
  end

  def transform_NodeDefinition(e)
    entries = [transform(e.host_matches).with_name('matches')]
    entries << transform(e.parent).with_name('parent') unless e.parent.nil?
    entries << block_as_entry('body', e.body) unless e.body.nil?
    PN::Map.new(entries).as_call('node')
  end

  def transform_Nop(_)
    PN::Call.new('nop')
  end

  def transform_NotExpression(e)
    PN::Call.new('!', transform(e.expr))
  end

  def transform_OrExpression(e)
    binary_op(e, 'or')
  end

  def transform_Parameter(e)
    entries = [PN::Literal.new(e.name).with_name('name')]
    entries << transform(e.type_expr).with_name('type') unless e.type_expr.nil?
    entries << PN::Literal.new(true).with_name('splat') if e.captures_rest
    entries << transform(e.value).with_name('value') unless e.value.nil?
    PN::Map.new(entries).with_name('param')
  end

  def transform_ParenthesizedExpression(e)
    PN::Call.new('paren', transform(e.expr))
  end

  def transform_PlanDefinition(e)
    definition_to_pn(e, 'plan', nil, e.return_type)
  end

  def transform_Program(e)
    transform(e.body)
  end

  def transform_QualifiedName(e)
    PN::Call.new('qn', PN::Literal.new(e.value))
  end

  def transform_QualifiedReference(e)
    PN::Call.new('qr', PN::Literal.new(e.cased_value))
  end

  def transform_RelationshipExpression(e)
    binary_op(e, e.operator)
  end

  def transform_RenderExpression(e)
    PN::Call.new('render', transform(e.expr))
  end

  def transform_RenderStringExpression(e)
    PN::Literal.new(e.value).as_call('render-s')
  end

  def transform_ReservedWord(e)
    PN::Literal.new(e.word).as_call('reserved')
  end

  def transform_ResourceBody(e)
    PN::Map.new([
      transform(e.title).with_name('title'),
      transform(e.operations).with_name('ops')
    ]).as_call('resource_body')
  end

  def transform_ResourceDefaultsExpression(e)
    entries = [transform(e.type_ref).with_name('type'), transform(e.operations).with_name('ops')]
    entries << PN::Literal.new(e.form).with_name('form') unless e.form == 'regular'
    PN::Map.new(entries).as_call('resource-defaults')
  end

  def transform_ResourceExpression(e)
    entries = [
      transform(e.type_name).with_name('type'),
      PN::List.new(pn_array(e.bodies).map { |body| body[0] }).with_name('bodies')
    ]
    entries << PN::Literal.new(e.form).with_name('form') unless e.form == 'regular'
    PN::Map.new(entries).as_call('resource')
  end

  def transform_ResourceOverrideExpression(e)
    entries = [transform(e.resources).with_name('resources'), transform(e.operations).with_name('ops')]
    entries << PN::Literal.new(e.form).with_name('form') unless e.form == 'regular'
    PN::Map.new(entries).as_call('resource-override')
  end

  def transform_ResourceTypeDefinition(e)
    definition_to_pn(e, 'define')
  end

  def transform_SelectorEntry(e)
    PN::Call.new('=>', transform(e.matching_expr), transform(e.value_expr))
  end

  def transform_SelectorExpression(e)
    PN::Call.new('?', transform(e.left_expr), transform(e.selectors))
  end

  def transform_SiteDefinition(e)
    transform(e.body).as_call('site')
  end

  def transform_SubLocatedExpression(e)
    transform(e.expr)
  end

  def transform_TextExpression(e)
    PN::Call.new('str', transform(e.expr))
  end

  def transform_TypeAlias(e)
    PN::Call.new('type-alias', PN::Literal.new(e.name), transform(e.type_expr))
  end

  def transform_TypeDefinition(e)
    PN::Call.new('type-definition', PN::Literal.new(e.name), PN::Literal.new(e.parent), transform(e.body))
  end

  def transform_TypeMapping(e)
    PN::Call.new('type-mapping', transform(e.type_expr), transform(e.mapping_expr))
  end

  def transform_UnaryMinusExpression(e)
    if e.expr.is_a?(LiteralValue)
      v = e.expr.value
      if v.is_a?(Numeric)
        return PN::Literal.new(-v)
      end
    end
    PN::Call.new('-', transform(e.expr))
  end

  def transform_UnfoldExpression(e)
    PN::Call.new('unfold', transform(e.expr))
  end

  def transform_UnlessExpression(e)
    if_to_pn(e, 'unless')
  end

  def transform_VariableExpression(e)
    ne = e.expr
    PN::Call.new('var', ne.is_a?(Model::QualifiedName) ? PN::Literal.new(ne.value) : transform(ne))
  end

  def transform_VirtualQuery(e)
    is_nop?(e.expr) ? PN::Call.new('virtual-query') : PN::Call.new('virtual-query', transform(e.expr))
  end

  def is_nop?(e)
    e.nil? || e.is_a?(Nop)
  end

  def binary_op(e, op)
    PN::Call.new(op, transform(e.left_expr), transform(e.right_expr))
  end

  def definition_to_pn(e, type_name, parent = nil, return_type = nil)
    entries = [PN::Literal.new(e.name).with_name('name')]
    entries << PN::Literal.new(parent).with_name('parent') unless parent.nil?
    entries << parameters_entry(e.parameters) unless e.parameters.empty?
    entries << block_as_entry('body', e.body) unless e.body.nil?
    entries << transform(return_type).with_name('returns') unless return_type.nil?
    PN::Map.new(entries).as_call(type_name)
  end

  def parameters_entry(parameters)
    PN::Map.new(parameters.map do |p|
      entries = []
      entries << transform(p.type_expr).with_name('type') unless p.type_expr.nil?
      entries << PN::Literal(true).with_name('splat') if p.captures_rest
      entries << transform(p.value).with_name('value') unless p.value.nil?
      PN::Map.new(entries).with_name(p.name)
    end).with_name('params')
  end

  def block_as_entry(name, expr)
    if expr.is_a?(BlockExpression)
      transform(expr.statements).with_name(name)
    else
      transform([expr]).with_name(name)
    end
  end

  def pn_array(a)
    a.map { |e| transform(e) }
  end

  def call_to_pn(e, r, nr)
    entries = [transform(e.functor_expr).with_name('functor'), transform(e.arguments).with_name('args')]
    entries << transform(e.lambda).with_name('block') unless e.lambda.nil?
    PN::Map.new(entries).as_call(e.rval_required ? r : nr)
  end

  def if_to_pn(e, name)
    entries = [transform(e.test).with_name('test')]
    entries << block_as_entry('then', e.then_expr) unless is_nop?(e.then_expr)
    entries << block_as_entry('else', e.else_expr) unless is_nop?(e.else_expr)
    PN::Map.new(entries).as_call(name)
  end
end

end
end
