# Dumps a Pops::Model in reverse polish notation; i.e. LISP style
# The intention is to use this for debugging output
# TODO: BAD NAME - A DUMP is a Ruby Serialization
#
class Puppet::Pops::Model::ModelTreeDumper < Puppet::Pops::Model::TreeDumper
  def dump_Array o
    o.collect {|e| do_dump(e) }
  end

  def dump_LiteralFloat o
    o.value.to_s
  end

  def dump_LiteralInteger o
    case o.radix
    when 10
      o.value.to_s
    when 8
      "0%o" % o.value
    when 16
      "0x%X" % o.value
    else
      "bad radix:" + o.value.to_s
    end
  end

  def dump_LiteralValue o
    o.value.to_s
  end

  def dump_Factory o
    do_dump(o.current)
  end

  def dump_Application o
    ["application", o.name, do_dump(o.parameters), do_dump(o.body)]
  end

  def dump_ArithmeticExpression o
    [o.operator.to_s, do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  # x[y] prints as (slice x y)
  def dump_AccessExpression o
    if o.keys.size <= 1
      ["slice", do_dump(o.left_expr), do_dump(o.keys[0])]
    else
      ["slice", do_dump(o.left_expr), do_dump(o.keys)]
    end
  end

  def dump_MatchesExpression o
    [o.operator.to_s, do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_CollectExpression o
    result = ["collect", do_dump(o.type_expr), :indent, :break, do_dump(o.query), :indent]
    o.operations do |ao|
      result << :break << do_dump(ao)
    end
    result += [:dedent, :dedent ]
    result
  end

  def dump_EppExpression o
    result = ["epp"]
#    result << ["parameters"] + o.parameters.collect {|p| do_dump(p) } if o.parameters.size() > 0
    if o.body
      result << do_dump(o.body)
    else
      result << []
    end
    result
  end

  def dump_ExportedQuery o
    result = ["<<| |>>"]
    result += dump_QueryExpression(o) unless is_nop?(o.expr)
    result
  end

  def dump_VirtualQuery o
    result = ["<| |>"]
    result += dump_QueryExpression(o) unless is_nop?(o.expr)
    result
  end

  def dump_QueryExpression o
    [do_dump(o.expr)]
  end

  def dump_ComparisonExpression o
    [o.operator.to_s, do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_AndExpression o
    ["&&", do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_OrExpression o
    ["||", do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_InExpression o
    ["in", do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_AssignmentExpression o
    [o.operator.to_s, do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  # Produces (name => expr) or (name +> expr)
  def dump_AttributeOperation o
    [o.attribute_name, o.operator, do_dump(o.value_expr)]
  end

  def dump_AttributesOperation o
    ['* =>', do_dump(o.expr)]
  end

  def dump_LiteralList o
    ["[]"] + o.values.collect {|x| do_dump(x)}
  end

  def dump_LiteralHash o
    ["{}"] + o.entries.collect {|x| do_dump(x)}
  end

  def dump_KeyedEntry o
    [do_dump(o.key), do_dump(o.value)]
  end

  def dump_MatchExpression o
    [o.operator.to_s, do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_LiteralString o
    "'#{o.value}'"
  end

  def dump_LambdaExpression o
    result = ["lambda"]
    result << ["parameters"] + o.parameters.collect {|p| do_dump(p) } if o.parameters.size() > 0
    if o.body
      result << do_dump(o.body)
    else
      result << []
    end
    result
  end

  def dump_LiteralDefault o
    ":default"
  end

  def dump_LiteralUndef o
    ":undef"
  end

  def dump_LiteralRegularExpression o
    "/#{o.value.source}/"
  end

  def dump_Nop o
    ":nop"
  end

  def dump_NamedAccessExpression o
    [".", do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_NilClass o
    "()"
  end

  def dump_NotExpression o
    ['!', dump(o.expr)]
  end

  def dump_VariableExpression o
    "$#{dump(o.expr)}"
  end

  # Interpolation (to string) shown as (str expr)
  def dump_TextExpression o
    ["str", do_dump(o.expr)]
  end

  def dump_UnaryMinusExpression o
    ['-', do_dump(o.expr)]
  end

  def dump_UnfoldExpression o
    ['unfold', do_dump(o.expr)]
  end

  def dump_BlockExpression o
    result = ["block", :indent]
    o.statements.each {|x| result << :break; result << do_dump(x) }
    result << :dedent << :break
    result
  end

  # Interpolated strings are shown as (cat seg0 seg1 ... segN)
  def dump_ConcatenatedString o
    ["cat"] + o.segments.collect {|x| do_dump(x)}
  end

  def dump_HeredocExpression(o)
    result = ["@(#{o.syntax})", :indent, :break, do_dump(o.text_expr), :dedent, :break]
  end

  def dump_HostClassDefinition o
    result = ["class", o.name]
    result << ["inherits", o.parent_class] if o.parent_class
    result << ["parameters"] + o.parameters.collect {|p| do_dump(p) } if o.parameters.size() > 0
    if o.body
      result << do_dump(o.body)
    else
      result << []
    end
    result
  end

  def dump_NodeDefinition o
    result = ["node"]
    result << ["matches"] + o.host_matches.collect {|m| do_dump(m) }
    result << ["parent", do_dump(o.parent)] if o.parent
    if o.body
      result << do_dump(o.body)
    else
      result << []
    end
    result
  end

  def dump_SiteDefinition o
    result = ["site"]
    if o.body
      result << do_dump(o.body)
    else
      result << []
    end
    result
  end

  def dump_NamedDefinition o
    # the nil must be replaced with a string
    result = [nil, o.name]
    result << ["parameters"] + o.parameters.collect {|p| do_dump(p) } if o.parameters.size() > 0
    if o.body
      result << do_dump(o.body)
    else
      result << []
    end
    result
  end

  def dump_ResourceTypeDefinition o
    result = dump_NamedDefinition(o)
    result[0] = 'define'
    result
  end

  def dump_CapabilityMapping o
    [o.kind, do_dump(o.component), o.capability, do_dump(o.mappings)]
  end

  def dump_ResourceOverrideExpression o
    form = o.form == :regular ? '' : o.form.to_s + "-"
    result = [form+"override", do_dump(o.resources), :indent]
    o.operations.each do |p|
      result << :break << do_dump(p)
    end
    result << :dedent
    result
  end

  def dump_ReservedWord o
    [ 'reserved', o.word ]
  end

  # Produces parameters as name, or (= name value)
  def dump_Parameter o
    name_prefix = o.captures_rest ? '*' : ''
    name_part = "#{name_prefix}#{o.name}"
    if o.value && o.type_expr
      ["=t", do_dump(o.type_expr), name_part, do_dump(o.value)]
    elsif o.value
      ["=", name_part, do_dump(o.value)]
    elsif o.type_expr
      ["t", do_dump(o.type_expr), name_part]
    else
      name_part
    end
  end

  def dump_ParenthesizedExpression o
    do_dump(o.expr)
  end

  # Hides that Program exists in the output (only its body is shown), the definitions are just
  # references to contained classes, resource types, and nodes
  def dump_Program(o)
    dump(o.body)
  end

  def dump_IfExpression o
    result = ["if", do_dump(o.test), :indent, :break,
      ["then", :indent, do_dump(o.then_expr), :dedent]]
    result +=
    [:break,
      ["else", :indent, do_dump(o.else_expr), :dedent],
      :dedent] unless is_nop? o.else_expr
    result
  end

  def dump_UnlessExpression o
    result = ["unless", do_dump(o.test), :indent, :break,
      ["then", :indent, do_dump(o.then_expr), :dedent]]
    result +=
    [:break,
      ["else", :indent, do_dump(o.else_expr), :dedent],
      :dedent] unless is_nop? o.else_expr
    result
  end

  # Produces (invoke name args...) when not required to produce an rvalue, and
  # (call name args ... ) otherwise.
  #
  def dump_CallNamedFunctionExpression o
    result = [o.rval_required ? "call" : "invoke", do_dump(o.functor_expr)]
    o.arguments.collect {|a| result << do_dump(a) }
    result
  end

  #    def dump_CallNamedFunctionExpression o
  #      result = [o.rval_required ? "call" : "invoke", do_dump(o.functor_expr)]
  #      o.arguments.collect {|a| result << do_dump(a) }
  #      result
  #    end

  def dump_CallMethodExpression o
    result = [o.rval_required ? "call-method" : "invoke-method", do_dump(o.functor_expr)]
    o.arguments.collect {|a| result << do_dump(a) }
    result << do_dump(o.lambda) if o.lambda
    result
  end

  def dump_CaseExpression o
    result = ["case", do_dump(o.test), :indent]
    o.options.each do |s|
      result << :break << do_dump(s)
    end
    result << :dedent
  end

  def dump_CaseOption o
    result = ["when"]
    result << o.values.collect {|x| do_dump(x) }
    result << ["then", do_dump(o.then_expr) ]
    result
  end

  def dump_RelationshipExpression o
    [o.operator.to_s, do_dump(o.left_expr), do_dump(o.right_expr)]
  end

  def dump_RenderStringExpression o
    ["render-s", " '#{o.value}'"]
  end

  def dump_RenderExpression o
    ["render", do_dump(o.expr)]
  end

  def dump_ResourceBody o
    result = [do_dump(o.title), :indent]
    o.operations.each do |p|
      result << :break << do_dump(p)
    end
    result << :dedent
    result
  end

  def dump_ResourceDefaultsExpression o
    form = o.form == :regular ? '' : o.form.to_s + "-"
    result = [form+"resource-defaults", do_dump(o.type_ref), :indent]
    o.operations.each do |p|
      result << :break << do_dump(p)
    end
    result << :dedent
    result
  end

  def dump_ResourceExpression o
    form = o.form == :regular ? '' : o.form.to_s + "-"
    result = [form+"resource", do_dump(o.type_name), :indent]
    o.bodies.each do |b|
      result << :break << do_dump(b)
    end
    result << :dedent
    result
  end

  def dump_SelectorExpression o
    ["?", do_dump(o.left_expr)] + o.selectors.collect {|x| do_dump(x) }
  end

  def dump_SelectorEntry o
    [do_dump(o.matching_expr), "=>", do_dump(o.value_expr)]
  end

  def dump_SubLocatedExpression o
    ["sublocated", do_dump(o.expr)]
  end

  def dump_TypeAlias(o)
    ['type-alias', o.name, do_dump(o.type_expr)]
  end

  def dump_TypeMapping(o)
    ['type-mapping', do_dump(o.type_expr), do_dump(o.mapping_expr)]
  end

  def dump_TypeDefinition(o)
    ['type-definition', o.name, o.parent, do_dump(o.body)]
  end

  def dump_Object o
    [o.class.to_s, o.to_s]
  end

  def is_nop? o
    o.nil? || o.is_a?(Puppet::Pops::Model::Nop)
  end
end
