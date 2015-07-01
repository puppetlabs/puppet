require 'rgen/metamodel_builder'

# The Bindings model is a model of Key to Producer mappings (bindings).
# The central concept is that a Bindings is a nested structure of bindings.
# A top level Bindings should be a NamedBindings (the name is used primarily
# in error messages). A Key is a Type/Name combination.
#
# TODO: In this version, references to "any object" uses the class Object,
#       but this is only temporary. The intent is to use specific Puppet Objects
#       that are typed using the Puppet Type System (to enable serialization).
#
# @see Puppet::Pops::Binder::BindingsFactory The BindingsFactory for more details on how to create model instances.
# @api public
module Puppet::Pops::Binder::Bindings
  extend RGen::MetamodelBuilder::ModuleExtension

  # This declaration is used to overcome bugs in RGen. What is really wanted is an Opaque Object
  # type that does not serialize its values, but such an type does not work when recreating the
  # meta model from a dump.
  # Instead, after loading the model, the generated code for type validation must be patched
  #
  FakeObject = String

  # @abstract
  # @api public
  class BindingsModelObject < RGen::MetamodelBuilder::MMBase
    abstract
  end

  # @abstract
  # @api public
  #
  class AbstractBinding < BindingsModelObject
    abstract
  end

  # An abstract producer
  # @abstract
  # @api public
  #
  class ProducerDescriptor < BindingsModelObject
    abstract
    contains_one_uni 'transformer', Puppet::Pops::Model::LambdaExpression
  end
  # All producers are singleton producers unless wrapped in a non caching producer
  # where each lookup produces a new instance. It is an error to have a nesting level > 1
  # and to nest a NonCachingProducerDescriptor.
  #
  # @api public
  #
  class NonCachingProducerDescriptor < ProducerDescriptor
    contains_one_uni 'producer', ProducerDescriptor
  end

  # Produces a constant value (i.e. something of {Puppet::Pops::Types::PDataType PDataType})
  # @api public
  #
  class ConstantProducerDescriptor < ProducerDescriptor
    # TODO: This should be a typed Puppet Object
    has_attr 'value', FakeObject
  end

  # Produces a value by evaluating a Puppet DSL expression.
  # Note that the expression is not contained as it is part of a Puppet::Pops::Model::Program.
  # To include the expression in the serialization, the Program it is contained in must be
  # contained in the same serialization. This can be achieved by containing it in the
  # ContributedBindings that is the top of a BindingsModel produced and given to the Injector.
  #
  # @api public
  #
  class EvaluatingProducerDescriptor < ProducerDescriptor
    has_one 'expression', Puppet::Pops::Model::Expression
  end

  # An InstanceProducer creates an instance of the given class
  # Arguments are passed to the class' `new` operator in the order they are given.
  # @api public
  #
  class InstanceProducerDescriptor < ProducerDescriptor
    # TODO: This should be a typed Puppet Object ??
    has_many_attr 'arguments', FakeObject, :upperBound => -1
    has_attr 'class_name', String
  end

  # A ProducerProducerDescriptor, describes that the produced instance is itself a Producer
  # that should be used to produce the value.
  # @api public
  #
  class ProducerProducerDescriptor < ProducerDescriptor
    contains_one_uni 'producer', ProducerDescriptor, :lowerBound => 1
  end

  # Produces a value by looking up another key (type/name)
  # @api public
  #
  class LookupProducerDescriptor < ProducerDescriptor
    has_attr 'type', Object
    has_attr 'name', String
  end

  # Produces a value by looking up another multibound key, and then looking up
  # the detail using a detail_key.
  # This is used to produce a specific service of a given type (such as a SyntaxChecker for the syntax "json").
  # @api public
  #
  class HashLookupProducerDescriptor < LookupProducerDescriptor
    has_attr 'key', String
  end

  # Produces a value by looking up each producer in turn. The first existing producer wins.
  # @api public
  #
  class FirstFoundProducerDescriptor < ProducerDescriptor
    contains_many_uni 'producers', LookupProducerDescriptor
  end

  # @api public
  # @abstract
  class MultibindProducerDescriptor < ProducerDescriptor
    abstract
  end

  # Used in a Multibind of Array type unless it has a producer. May explicitly be used as well.
  # @api public
  #
  class ArrayMultibindProducerDescriptor < MultibindProducerDescriptor
  end

  # Used in a Multibind of Hash type unless it has a producer. May explicitly be used as well.
  # @api public
  #
  class HashMultibindProducerDescriptor < MultibindProducerDescriptor
  end

  # Plays the role of "Hash[String, Object] entry" but with keys in defined order.
  #
  # @api public
  #
  class NamedArgument < BindingsModelObject
    has_attr 'name', String, :lowerBound => 1
    has_attr 'value', FakeObject
  end

  # Binds a type/name combination to a producer. Optionally marking the bindidng as being abstract, or being an
  # override of another binding. Optionally, the binding defines producer arguments passed to the producer when
  # it is created.
  #
  # @api public
  class Binding < AbstractBinding
    has_attr 'type', Object
    has_attr 'name', String
    has_attr 'override', Boolean
    has_attr 'abstract', Boolean
    has_attr 'final', Boolean
    # If set is a contribution in a multibind
    has_attr 'multibind_id', String, :lowerBound => 0
    # Invariant: Only multibinds may have lowerBound 0, all regular Binding must have a producer.
    contains_one_uni 'producer', ProducerDescriptor, :lowerBound => 0
    contains_many_uni 'producer_args', NamedArgument, :lowerBound => 0
  end


  # A multibinding is a binding other bindings can contribute to.
  #
  # @api public
  class Multibinding < Binding
    has_attr 'id', String
  end

  # A container of Binding instances
  # @api public
  #
  class Bindings < AbstractBinding
    contains_many_uni 'bindings', AbstractBinding
  end

  # The top level container of bindings can have a name (for error messages, logging, tracing).
  # May be nested.
  # @api public
  #
  class NamedBindings < Bindings
    has_attr 'name', String
  end

  # A named layer of bindings having the same priority.
  # @api public
  class NamedLayer < BindingsModelObject
    has_attr 'name', String, :lowerBound => 1
    contains_many_uni 'bindings', NamedBindings
  end

  # A list of layers with bindings in descending priority order.
  # @api public
  #
  class LayeredBindings < BindingsModelObject
    contains_many_uni 'layers', NamedLayer
  end

  # ContributedBindings is a named container of one or more NamedBindings.
  # The intent is that a bindings producer returns a ContributedBindings that identifies the contributor
  # as opposed to the names of the different set of bindings. The ContributorBindings name is typically
  # a technical name that indicates their source (a service).
  #
  # When EvaluatingProducerDescriptor is used, it holds a reference to an Expression. That expression
  # should be contained in the programs referenced in the ContributedBindings that contains that producer.
  # While the bindings model will still work if this is not the case, it will not serialize and deserialize
  # correctly.
  #
  # @api public
  #
  class ContributedBindings < NamedLayer
    contains_many_uni 'programs', Puppet::Pops::Model::Program
  end

end
