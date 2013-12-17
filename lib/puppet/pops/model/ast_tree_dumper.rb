require 'puppet/parser/ast'

# Dumps a Pops::Model in reverse polish notation; i.e. LISP style
# The intention is to use this for debugging output
# TODO: BAD NAME - A DUMP is a Ruby Serialization
#
class Puppet::Pops::Model::AstTreeDumper < Puppet::Pops::Model::TreeDumper
  AST = Puppet::Parser::AST
  Model = Puppet::Pops::Model

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

  def dump_Expression(o)
    "(pops-expression #{Puppet::Pops::Model::ModelTreeDumper.new().dump(o.value)})"
  end

  def dump_Factory o
    do_dump(o.current)
  end

  def dump_ArithmeticOperator o
    [o.operator.to_s, do_dump(o.lval), do_dump(o.rval)]
  end
  def dump_Relationship o
    [o.arrow.to_s, do_dump(o.left), do_dump(o.right)]
  end

  # Hostname is tricky, it is either a bare word, a string, or default, or regular expression
  # Least evil, all strings except default are quoted
  def dump_HostName o
    result = do_dump o.value
    unless o.value.is_a? AST::Regex
      result = result == "default" ? ":default" : "'#{result}'"
    end
    result
  end

  # x[y] prints as (slice x y)
  def dump_HashOrArrayAccess o
    var = o.variable.is_a?(String) ? "$#{o.variable}" : do_dump(o.variable)
    ["slice", var, do_dump(o.key)]
  end

  # The AST Collection knows about exported or virtual query, not the query.
  def dump_Collection o
    result = ["collect", do_dump(o.type), :indent, :break]
    if o.form == :virtual
      q = ["<| |>"]
    else
      q = ["<<| |>>"]
    end
    q << do_dump(o.query) unless is_nop?(o.query)
    q <<  :indent
    result << q
    o.override do |ao|
      result << :break << do_dump(ao)
    end
    result += [:dedent, :dedent ]
    result
  end

  def dump_CollExpr o
    operator = case o.oper
    when 'and'
      '&&'
    when 'or'
      '||'
    else
      o.oper
    end
    [operator, do_dump(o.test1), do_dump(o.test2)]
  end

  def dump_ComparisonOperator o
    [o.operator.to_s, do_dump(o.lval), do_dump(o.rval)]
  end

  def dump_Boolean o
    o.to_s
  end

  def dump_BooleanOperator o
    operator = o.operator == 'and' ? '&&' : '||'
    [operator, do_dump(o.lval), do_dump(o.rval)]
  end

  def dump_InOperator o
    ["in", do_dump(o.lval), do_dump(o.rval)]
  end

  # $x = ...
  # $x += ...
  #
  def dump_VarDef o
    operator = o.append ? "+=" : "="
    [operator, '$' + do_dump(o.name), do_dump(o.value)]
  end

  # Produces (name => expr) or (name +> expr)
  def dump_ResourceParam o
    operator = o.add ? "+>" : "=>"
    [do_dump(o.param), operator, do_dump(o.value)]
  end

  def dump_Array o
    o.collect {|e| do_dump(e) }
  end

  def dump_ASTArray o
    ["[]"] + o.children.collect {|x| do_dump(x)}
  end

  def dump_ASTHash o
    ["{}"] + o.value.sort_by{|k,v| k.to_s}.collect {|x| [do_dump(x[0]), do_dump(x[1])]}
#    ["{}"] + o.value.collect {|x| [do_dump(x[0]), do_dump(x[1])]}
  end

  def dump_MatchOperator o
    [o.operator.to_s, do_dump(o.lval), do_dump(o.rval)]
  end

  # Dump a Ruby String in single quotes unless it is a number.
  def dump_String o

    if o.is_a? String
      o               # A Ruby String, not quoted
    elsif Puppet::Pops::Utils.to_n(o.value)
      o.value         # AST::String that is a number without quotes
    else
      "'#{o.value}'"  # AST::String that is not a number
    end
  end

  def dump_Lambda o
    result = ["lambda"]
    result << ["parameters"] + o.parameters.collect {|p| _dump_ParameterArray(p) } if o.parameters.size() > 0
    if o.children == []
      result << [] # does not have a lambda body
    else
      result << do_dump(o.children)
    end
    result
  end

  def dump_Default o
    ":default"
  end

  def dump_Undef o
    ":undef"
  end

  # Note this is Regex (the AST kind), not Ruby Regexp
  def dump_Regex o
    "/#{o.value.source}/"
  end

  def dump_Nop o
    ":nop"
  end

  def dump_NilClass o
    "()"
  end

  def dump_Not o
    ['!', dump(o.value)]
  end

  def dump_Variable o
    "$#{dump(o.value)}"
  end

  def dump_Minus o
    ['-', do_dump(o.value)]
  end

  def dump_BlockExpression o
    ["block"] + o.children.collect {|x| do_dump(x) }
  end

  # Interpolated strings are shown as (cat seg0 seg1 ... segN)
  def dump_Concat o
    ["cat"] + o.value.collect {|x| x.is_a?(AST::String) ? " "+do_dump(x) : ["str", do_dump(x)]}
  end

  def dump_Hostclass o
    # ok, this is kind of crazy stuff in the AST, information in a context instead of in AST, and
    # parameters are in a Ruby Array with each parameter being an Array...
    #
    context = o.context
    args = context[:arguments]
    parent = context[:parent]
    result = ["class", o.name]
    result << ["inherits", parent] if parent
    result << ["parameters"] + args.collect {|p| _dump_ParameterArray(p) } if args && args.size() > 0
    if is_nop?(o.code)
      result << []
    else
      result << do_dump(o.code)
    end
    result
  end

  def dump_Name o
    o.value
  end

  def dump_Node o
    context = o.context
    parent = context[:parent]
    code = context[:code]

    result = ["node"]
    result << ["matches"] + o.names.collect {|m| do_dump(m) }
    result << ["parent", do_dump(parent)] if !is_nop?(parent)
    if is_nop?(code)
      result << []
    else
      result << do_dump(code)
    end
    result
  end

  def dump_Definition o
    # ok, this is even crazier that Hostclass. The name of the define does not have an accessor
    # and some things are in the context (but not the name). Parameters are called arguments and they
    # are in a Ruby Array where each parameter is an array of 1 or 2 elements.
    #
    context = o.context
    name = o.instance_variable_get("@name")
    args = context[:arguments]
    code = context[:code]
    result = ["define", name]
    result << ["parameters"] + args.collect {|p| _dump_ParameterArray(p) } if args && args.size() > 0
    if is_nop?(code)
      result << []
    else
      result << do_dump(code)
    end
    result
  end

  def dump_ResourceReference o
    result = ["slice", do_dump(o.type)]
    if o.title.children.size == 1
      result << do_dump(o.title[0])
    else
      result << do_dump(o.title.children)
    end
    result
  end

  def dump_ResourceOverride o
    result = ["override", do_dump(o.object), :indent]
    o.parameters.each do |p|
      result << :break << do_dump(p)
    end
    result << :dedent
    result
  end

  # Puppet AST encodes a parameter as a one or two slot Array.
  # This is not a polymorph dump method.
  #
  def _dump_ParameterArray o
    if o.size == 2
      ["=", o[0], do_dump(o[1])]
    else
      o[0]
    end
  end

  def dump_IfStatement o
    result = ["if", do_dump(o.test), :indent, :break,
      ["then", :indent, do_dump(o.statements), :dedent]]
    result +=
    [:break,
      ["else", :indent, do_dump(o.else), :dedent],
      :dedent] unless is_nop? o.else
    result
  end

  # Produces (invoke name args...) when not required to produce an rvalue, and
  # (call name args ... ) otherwise.
  #
  def dump_Function o
    # somewhat ugly as Function hides its "ftype" instance variable
    result = [o.instance_variable_get("@ftype") == :rvalue ? "call" : "invoke", do_dump(o.name)]
    o.arguments.collect {|a| result << do_dump(a) }
    result << do_dump(o.pblock) if o.pblock
    result
  end

  def dump_MethodCall o
    # somewhat ugly as Method call (does the same as function) and hides its "ftype" instance variable
    result = [o.instance_variable_get("@ftype") == :rvalue ? "call-method" : "invoke-method",
      [".", do_dump(o.receiver), do_dump(o.name)]]
    o.arguments.collect {|a| result << do_dump(a) }
    result << do_dump(o.lambda) if o.lambda
    result
  end

  def dump_CaseStatement o
    result = ["case", do_dump(o.test), :indent]
    o.options.each do |s|
      result << :break << do_dump(s)
    end
    result << :dedent
  end

  def dump_CaseOpt o
    result = ["when"]
    result << o.value.collect {|x| do_dump(x) }
    # A bit of trickery to get it into the same shape as Pops output
    if is_nop?(o.statements)
      result << ["then", []]  # Puppet AST has a nop if there is no body
    else
      result << ["then", do_dump(o.statements) ]
    end
    result
  end

  def dump_ResourceInstance o
    result = [do_dump(o.title), :indent]
    o.parameters.each do |p|
      result << :break << do_dump(p)
    end
    result << :dedent
    result
  end

  def dump_ResourceDefaults o
    result = ["resource-defaults", do_dump(o.type), :indent]
    o.parameters.each do |p|
      result << :break << do_dump(p)
    end
    result << :dedent
    result
  end

  def dump_Resource o
    if o.exported
      form = 'exported-'
    elsif o.virtual
      form = 'virtual-'
    else
      form = ''
    end
    result = [form+"resource", do_dump(o.type), :indent]
    o.instances.each do |b|
      result << :break << do_dump(b)
    end
    result << :dedent
    result
  end

  def dump_Selector o
    values = o.values
    values = [values] unless values.instance_of? AST::ASTArray or values.instance_of? Array
    ["?", do_dump(o.param)] + values.collect {|x| do_dump(x) }
  end

  def dump_Object o
    ['dev-error-no-polymorph-dump-for:', o.class.to_s, o.to_s]
  end

  def is_nop? o
    o.nil? || o.is_a?(Model::Nop) || o.is_a?(AST::Nop)
  end
end
