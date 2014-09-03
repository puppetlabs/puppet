
# Dumps a Pops::Binder::Bindings model in reverse polish notation; i.e. LISP style
# The intention is to use this for debugging output
# TODO: BAD NAME - A DUMP is a Ruby Serialization
# NOTE: use :break, :indent, :dedent in lists to do just that
#
class Puppet::Pops::Binder::BindingsModelDumper < Puppet::Pops::Model::TreeDumper
  Bindings = Puppet::Pops::Binder::Bindings

  attr_reader :type_calculator
  attr_reader :expression_dumper

  def initialize
    super
    @type_calculator = Puppet::Pops::Types::TypeCalculator.new()
    @expression_dumper = Puppet::Pops::Model::ModelTreeDumper.new()
  end

  def dump_BindingsFactory o
    do_dump(o.model)
  end

  def dump_BindingsBuilder o
    do_dump(o.model)
  end

  def dump_BindingsContainerBuilder o
    do_dump(o.model)
  end

  def dump_NamedLayer o
    result = ['named-layer', (o.name.nil? ? '<no-name>': o.name), :indent]
    if o.bindings
      o.bindings.each do |b|
        result << :break
        result << do_dump(b)
      end
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

  def dump_Object o
    ['dev-error-no-polymorph-dump-for:', o.class.to_s, o.to_s]
  end

  def is_nop? o
    o.nil? || o.is_a?(Model::Nop) || o.is_a?(AST::Nop)
  end

  def dump_ProducerDescriptor o
     result = [o.class.name]
     result << expression_dumper.dump(o.transformer) if o.transformer
     result
  end

  def dump_NonCachingProducerDescriptor o
    dump_ProducerDescriptor(o) + do_dump(o.producer)
  end

  def dump_ConstantProducerDescriptor o
    ['constant', do_dump(o.value)]
  end

  def dump_EvaluatingProducerDescriptor o
    result = dump_ProducerDescriptor(o)
    result << expression_dumper.dump(o.expression)
  end

  def dump_InstanceProducerDescriptor o
    # TODO: o.arguments, o. transformer
    ['instance', o.class_name]
  end

  def dump_ProducerProducerDescriptor o
    # skip the transformer lambda...
    result = ['producer-producer', do_dump(o.producer)]
    result << expression_dumper.dump(o.transformer) if o.transformer
    result
  end

  def dump_LookupProducerDescriptor o
    ['lookup', do_dump(o.type), o.name]
  end

  def dump_PAnyType o
    type_calculator.string(o)
  end

  def dump_HashLookupProducerDescriptor o
    # TODO: transformer lambda
    result = ['hash-lookup', do_dump(o.type), o.name, "[#{do_dump(o.key)}]"]
    result << expression_dumper.dump(o.transformer) if o.transformer
    result
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
    result << "(in #{o.multibind_id})" if o.multibind_id
    result << ['to', do_dump(o.producer)] + do_dump(o.producer_args)
    result
  end

  def dump_Multibinding o
    result = ['multibind', o.id]
    result << 'override' if o.override
    result << 'abstract' if o.abstract
    result.concat([do_dump(o.type), o.name])
    result << "(in #{o.multibind_id})" if o.multibind_id
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

  def dump_LayeredBindings o
    result = ['layers', :indent]
      o.layers.each do |layer|
        result << :break
        result << do_dump(layer)
      end
    result << :dedent
    result
  end

  def dump_ContributedBindings o
    ['contributed', o.name, do_dump(o.bindings)]
  end
end
