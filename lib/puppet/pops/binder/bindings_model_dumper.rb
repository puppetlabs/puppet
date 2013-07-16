
# Dumps a Pops::Binder::Bindings model in reverse polish notation; i.e. LISP style
# The intention is to use this for debugging output
# TODO: BAD NAME - A DUMP is a Ruby Serialization
# NOTE: use :break, :indent, :dedent in lists to do just that
#
class Puppet::Pops::Binder::BindingsModelDumper < Puppet::Pops::Model::TreeDumper
  Bindings = Puppet::Pops::Binder::Bindings

  attr_reader :type_calculator

  def initialize
    super
    @type_calculator = Puppet::Pops::Types::TypeCalculator.new()
  end

  def dump_BindingsFactory o
    do_dump(o.model)
  end

  def dump_NamedLayer o
    result = ['named-layer', o.name, :indent]
    o.bindings.each do |b|
      result << :break
      result << do_dump(b)
    end
    result << :dedent
    result
  end


  def dump_Array o
    o.collect {|e| do_dump(e) }
  end

  def dump_ASTArray o
    ["[]"] + o.children.collect {|x| do_dump(x)}
  end

  def dump_ASTHash o
    ["{}"] + o.value.sort_by{|k,v| k.to_s}.collect {|x| [do_dump(x[0]), do_dump(x[1])]}
  end

  def dump_Integer o
    o.to_s
  end

  # Dump a Ruby String in single quotes unless it is a number.
  def dump_String o
    "'#{o}'"
  end

  def dump_NilClass o
    "()"
  end

#  def dump_Hostclass o
#    # ok, this is kind of crazy stuff in the AST, information in a context instead of in AST, and
#    # parameters are in a Ruby Array with each parameter being an Array...
#    #
#    context = o.context
#    args = context[:arguments]
#    parent = context[:parent]
#    result = ["class", o.name]
#    result << ["inherits", parent] if parent
#    result << ["parameters"] + args.collect {|p| _dump_ParameterArray(p) } if args && args.size() > 0
#    if is_nop?(o.code)
#      result << []
#    else
#      result << do_dump(o.code)
#    end
#    result
#  end



  def dump_Object o
    ['dev-error-no-polymorph-dump-for:', o.class.to_s, o.to_s]
  end

  def is_nop? o
    o.nil? || o.is_a?(Model::Nop) || o.is_a?(AST::Nop)
  end

  def dump_ProducerDescriptor o
    # TODO: delegate to Pops Model Tree dumper and dump the transformer if it exists
    # o.transformer
     [o.class.name ]
  end

  def dump_NonCachingProducerDescriptor o
    dump_ProducerDescriptor(o) + do_dump(o.producer)
  end

  def dump_ConstantProducerDescriptor o
    ['constant', do_dump(o.value)]
  end

  def dump_EvaluatingProducerDescriptor o
    # TODO: puppet pops model transformer dump o.expression
    dump_ProducerDescriptor(o)
  end

  def dump_InstanceProducerDescriptor
    # TODO: o.arguments, o. transformer
    ['instance', o.class_name]
  end

  def dump_ProducerProducerDescriptor o
    # skip the transformer lambda...
    ['producer-producer', do_dump(o.producer)]
  end

  def dump_LookupProducerDescriptor o
    ['lookup', do_dump(o.type), o.name]
  end

  def dump_PObjectType o
    type_calculator.string(o)
  end

  def dump_HashLookupProducerDescriptor o
    # TODO: transformer lambda
    ['hash-lookup', do_dump(o.type), o.name, "[#{do_dump(o.key)}]"]
  end

  def dump_FirstFoundProducerDescriptor o
    # TODO: transformer lambda
    ['first-found', do_dump(o.producers)]
  end

  def dump_ArrayMultibindProducerDescriptor o
    ['multibind-array']
  end

  def dump_HashMultibindProducerDescriptor o
    ['multibind-hash']
  end

  def dump_NamedArgument o
    "#{o.name} => #{do_dump(o.value)}"
  end

  def dump_Binding o
    result = ['bind']
    result << 'override' if o.override
    result << 'abstract' if o.abstract
    result.concat([do_dump(o.type), o.name])
    result << ['to', do_dump(o.producer)] + do_dump(o.producer_args)
    result
  end

  def dump_Multibinding o
    result = ['multibind', o.id]
    result << 'override' if o.override
    result << 'abstract' if o.abstract
    result.concat([do_dump(o.type), o.name])
    result << ['to', do_dump(o.producer)] + do_dump(o.producer_args)
    result
  end

  def dump_MultibindContribution o
    result = ['contribute-to', o.multibind_id]
    result << 'override' if o.override
    result << 'abstract' if o.abstract
    result.concat([do_dump(o.type), o.name])
    result << ['to', do_dump(o.producer)] + do_dump(o.producer_args)
    result
  end

  def dump_Bindings o
    do_dump(o.bindings)
  end

  def dump_NamedBindings o
    result = ['named-bindings', o.name, :indent]
    o.bindings.each do |b|
      result << :break
      result << do_dump(b)
    end
    result << :dedent
    result
  end

  def dump_Category o
    ['category', o.categorization, do_dump(o.value)]
  end

  def dump_CategorizedBindings o
    result = ['when', do_dump(o.predicates), :indent]
    o.bindings.each do |b|
      result << :break
      result << do_dump(b)
    end
    result << :dedent
    result
  end

  def dump_LayeredBindings o
    result = ['layers', :indent]
      o.layers.each do |layer|
        result << :break
        result << do_dump(layer)
      end
    result << :dedent
    result
  end

  def dump_EffectiveCategories o
    ['categories', do_dump(o.categories)]
  end

  def dump_ContributedBindings o
    ['contributed', o.name, do_dump(o.effective_categories), do_dump(o.bindings)]
  end
end
