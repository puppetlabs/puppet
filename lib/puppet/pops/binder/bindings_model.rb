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
# @see Puppet::Pops::Binder::BindingsFactory The BindingsFactory for more details on how to create model instances.
# @api public
module Puppet::Pops::Binder::Bindings

  # @abstract
  # @api public
  #
  class AbstractBinding < Puppet::Pops::Model::PopsObject
    abstract
  end

  # An abstract producer
  # @abstract
  # @api public
  #
  class ProducerDescriptor < Puppet::Pops::Model::PopsObject
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
    has_attr 'value', Object
  end

  # Produces a value by evaluating a Puppet DSL expression
  # @api public
  #
  class EvaluatingProducerDescriptor < ProducerDescriptor
    contains_one_uni 'expression', Puppet::Pops::Model::Expression
  end

  # An InstanceProducer creates an instance of the given class
  # Arguments are passed to the class' `new` operator in the order they are given.
  # @api public
  #
  class InstanceProducerDescriptor < ProducerDescriptor
    # TODO: This should be a typed Puppet Object ??
    has_many_attr 'arguments', Object, :upperBound => -1
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
    contains_one_uni 'type', Puppet::Pops::Types::PObjectType
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
  class NamedArgument < Puppet::Pops::Model::PopsObject
    has_attr 'name', String, :lowerBound => 1
    has_attr 'value', Object, :lowerBound => 1
  end

  # Binds a type/name combination to a producer. Optionally marking the bindidng as being abstract, or being an
  # override of another binding. Optionally, the binding defines producer arguments passed to the producer when
  # it is created.
  #
  # @api public
  class Binding < AbstractBinding
    contains_one_uni 'type', Puppet::Pops::Types::PObjectType
    has_attr 'name', String
    has_attr 'override', Boolean
    has_attr 'abstract', Boolean
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

  # A binding in a multibind
  # @api public
  #
  class MultibindContribution < Binding
    has_attr 'multibind_id', String, :lowerBound => 1
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

  # A category predicate (the request has to be in this category).
  # @api public
  #
  class Category < Puppet::Pops::Model::PopsObject
    has_attr 'categorization', String, :lowerBound => 1
    has_attr 'value', String, :lowerBound => 1
  end

  # A container of Binding instances that are in effect when the
  # predicates (min one) evaluates to true. Multiple predicates are handles as an 'and'.
  # Note that 'or' semantics are handled by repeating the same rules.
  # @api public
  #
  class CategorizedBindings < Bindings
    contains_many_uni 'predicates', Category, :lowerBound => 1
  end

  # A named layer of bindings having the same priority.
  # @api public
  class NamedLayer < Puppet::Pops::Model::PopsObject
    has_attr 'name', String, :lowerBound => 1
    contains_many_uni 'bindings', NamedBindings
  end

  # A list of layers with bindings in descending priority order.
  # @api public
  #
  class LayeredBindings < Puppet::Pops::Model::PopsObject
    contains_many_uni 'layers', NamedLayer
  end


  # A list of categroies consisting of categroization name and category value (i.e. the *state of the request*)
  # @api public
  #
  class EffectiveCategories < Puppet::Pops::Model::PopsObject
    # The order is from highest precedence to lowest
    contains_many_uni 'categories', Category
  end
end
