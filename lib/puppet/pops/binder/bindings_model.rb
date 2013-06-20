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

  class Producer < Puppet::Pops::Model::PopsObject
  end

  class NamedArgument < Puppet::Pops::Model::PopsObject
    has_attr 'name', String

    # TODO: this should be a typed Puppet Object
    has_attr 'value', Object
  end

  # A LiteralProducer produces a literal/data value.
  #
  class LiteralProducer < Producer
    # TODO: This should be a typed Puppet Object
    has_attr 'value', Object
  end

  # An InstanceProducer creates an instance of the given class
  # Arguments are passed to the class' `new` operator in the order they are given.
  #
  class InstanceProducer < ArgumentedProducer
    # TODO: This should be a typed Puppet Object
    contains_many_uni 'arguments', Object
    has_attr 'class_name', String
  end

  # Producer that provides an instance that in turn creates the looked up value
  # Named arguments are passed to the given class' new operator as an Array[NamedArgument]
  #
  class DynamicProducer < ArgumentedProducer
    contains_many_uni 'arguments', NamedArgument
    has_attr 'class_name', String
  end

  class Binding < AbstractBinding
    contains_one_uni 'type', Puppet::Pops::Types::PObjectType
    has_attr 'name', String
    has_attr 'override', Boolean
    has_attr 'abstract', Boolean
    contains_one_uni 'producer', Producer
  end

  class Multibinding < Binding
    has_attr 'id', String
    # TODO: Add the combinator as described in ARM-8
    # contains_one_uni 'combinator', [Puppet::Pops::Model::LambdaExpression]
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
  class CategoryPredicate < Puppet::Pops::Model::PopsObject
    has_attr 'categorization', String
    has_attr 'category', String
  end

  # A container of Binding instances that are in effect when the
  # predicates (min one) evaluates to true. Multiple predicates are handles as an 'and'.
  # Note that 'or' semantics are handled by repeating the same rules.
  #
  class CategorizedBindings < Bindings
    contains_many_uni 'predicates', CategoryPredicate, :lowerBound => 1
  end

end
