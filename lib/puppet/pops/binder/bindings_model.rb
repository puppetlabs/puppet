require 'rgen/metamodel_builder'

# The Bindings model is a model of Key to Producer mappings (bindings).
# The central concept is that a Bindings is a nested structure of bindings.
# A top level Bindings should be a NamedBindings (the name is used primarily
# in error messages). A Key is a Type/Name combination.
#
# TODO: In this version, references to "any object" uses the class Object.
#       this is only temporarily. The intent is to use specific Puppet Objects
#       that are typed using the Puppet Type System. (This to enable serialization)
#
module Puppet::Pops::Binder::Bindings

  class AbstractBinding < Puppet::Pops::Model::PopsObject
    abstract
  end

  # An abstract producer
  class ProducerDescriptor < Puppet::Pops::Model::PopsObject
    abstract
    contains_one_uni 'transformer', Puppet::Pops::Model::LambdaExpression
  end

  # All producers are singleton producers unless wrapped in a non caching producer
  # where each lookup produces a new instance. It is an error to have a nesting level > 1
  # and to nest a NonCachingProducerDescriptor.
  #
  class NonCachingProducerDescriptor < ProducerDescriptor
    contains_one_uni 'producer', ProducerDescriptor
  end

  # Produces a constant value (i.e. something of PDataType)
  #
  class ConstantProducerDescriptor < ProducerDescriptor
    # TODO: This should be a typed Puppet Object
    has_attr 'value', Object
  end

  # Produces a value by evaluating a Puppet DSL expression
  #
  class EvaluatingProducerDescriptor < ProducerDescriptor
    contains_one_uni 'expression', Puppet::Pops::Model::Expression
  end

  # An InstanceProducer creates an instance of the given class
  # Arguments are passed to the class' `new` operator in the order they are given.
  #
  class InstanceProducerDescriptor < ProducerDescriptor
    # TODO: This should be a typed Puppet Object ??
    has_many_attr 'arguments', Object, :upperBound => -1
    has_attr 'class_name', String
  end

  # A ProducerProducerDescriptor, describes that the produced instance is itself a Producer
  # that should be used to produce the value.
  #
  class ProducerProducerDescriptor < ProducerDescriptor
    contains_one_uni 'producer', ProducerDescriptor, :lowerBound => 1
  end

  # Produces a value by looking up another key (type/name)
  #
  class LookupProducerDescriptor < ProducerDescriptor
    contains_one_uni 'type', Puppet::Pops::Types::PObjectType
    has_attr 'name', String
  end

  # Produces a value by looking up another multibound key, and then looking up
  # the detail using a detail_key.
  # This is used to produce a specific service of a given type (such as a SyntaxChecker for the syntax "json").
  #
  class HashLookupProducerDescriptor < LookupProducerDescriptor
    has_attr 'key', String
  end

  # Produces a value by looking up each producer in turn. The first existing producer wins.
  #
  class FirstFoundProducerDescriptor < ProducerDescriptor
    contains_many_uni 'producers', LookupProducerDescriptor
  end

  class MultibindProducerDescriptor < ProducerDescriptor
    abstract
  end

  # Used in a Multibind of Array type unless it has a producer. May explicitly be used as well.
  class ArrayMultibindProducerDescriptor < MultibindProducerDescriptor
  end

  # Used in a Multibind of Hash type unless it has a producer. May explicitly be used as well.
  class HashMultibindProducerDescriptor < MultibindProducerDescriptor
  end

  class NamedArgument < Puppet::Pops::Model::PopsObject
    has_attr 'name', String, :lowerBound => 1
    has_attr 'value', Object, :lowerBound => 1
  end

  class Binding < AbstractBinding
    contains_one_uni 'type', Puppet::Pops::Types::PObjectType
    has_attr 'name', String
    has_attr 'override', Boolean
    has_attr 'abstract', Boolean
    # Invariant: Only multibinds may have lowerBound 0, all regular Binding must have a producer.
    contains_one_uni 'producer', ProducerDescriptor, :lowerBound => 0
    contains_many_uni 'producer_args', NamedArgument, :lowerBound => 0
  end


  class Multibinding < Binding
    has_attr 'id', String
  end

  # Binding in a multibind
  #
  class MultibindContribution < Binding
    has_attr 'multibind_id', String, :lowerBound => 1
  end

  # A container of Binding instances.
  #
  class Bindings < AbstractBinding
    contains_many_uni 'bindings', AbstractBinding
  end

  # The top level container of bindings can have a name (for error messages, logging, tracing).
  # May be nested.
  #
  class NamedBindings < Bindings
    has_attr 'name', String
  end

  # A category predicate (the request has to be in this category).
  #
  class Category < Puppet::Pops::Model::PopsObject
    has_attr 'categorization', String, :lowerBound => 1
    has_attr 'value', String, :lowerBound => 1
  end

  # A container of Binding instances that are in effect when the
  # predicates (min one) evaluates to true. Multiple predicates are handles as an 'and'.
  # Note that 'or' semantics are handled by repeating the same rules.
  #
  class CategorizedBindings < Bindings
    contains_many_uni 'predicates', Category, :lowerBound => 1
  end

  class NamedLayer < Puppet::Pops::Model::PopsObject
    has_attr 'name', String, :lowerBound => 1
    contains_many_uni 'bindings', NamedBindings
  end

  class LayeredBindings < Puppet::Pops::Model::PopsObject
    contains_many_uni 'layers', NamedLayer
  end


  class EffectiveCategories < Puppet::Pops::Model::PopsObject
    # The order is from highest precedence to lowest
    contains_many_uni 'categories', Category
  end
end
