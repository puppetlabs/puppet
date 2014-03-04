require 'rgen/metamodel_builder'

module Puppet::Biff::Model::PCore
  extend RGen::MetamodelBuilder::ModuleExtension

  # A base class for modeled objects that makes them Visitable, and Adaptable.
  # (This could be shared across all models in Puppet)
  #
  class PModelElement < RGen::MetamodelBuilder::MMBase
    include Puppet::Pops::Visitable
    include Puppet::Pops::Adaptable
    include Puppet::Pops::Containment
    abstract
  end

  # TODO: This should really be part of the type system directly
  # (Also, add EClassifier to PAbstractType)
  #
  class PTypeAlias < Puppet::Pops::Types::PAbstractType
    contains_one_uni 'real_type', Puppet::Pops::Types::PAbstractType, :lowerBound => 1
  end

  class PClassifier < PModelElement
    has_attr 'name', String, :lowerBound => 1
    # TODO: Reference to FunctionDefinitions
    # TODO: Reference to InvariantExpressions
  end

  class PTypeModel < PModelElement
    has_attr 'name', String
    has_attr 'ns_uri', String

    contains_many_uni 'type_declarations', PAbstractType, :lowerBound => 0
    contains_many_uni 'classifiers', PClassifier, :lowerBound => 0
  end

  class PAttribute < PModelElement
    has_attr 'default_value_literal', String
    has_attr 'synchronizeable', Boolean
    has_attr 'derived', Boolean
    has_attr 'transient', Boolean
    has_attr 'volatile', Boolean
    has_attr 'ordered', Boolean
    has_attr 'unique', Boolean

    # must be a reference to an PAbstractType contained by the PTypeModel containing this attribute's
    # containing PClassifier
    has_one 'p_attribute_type', PAbstractType, :lowerBound => 1
  end

  class PCatalogEntryClassifier < PClassifier
    contains_many_uni 'attributes', PAttribute, :lowerBound => 0
    abstract
  end

  # Concrete classifier for a HostClass
  class PHostClassClassifier < PCatalogEntryClassifier
  end

  # Concrete classifier for a Resource (type)
  class PResourceClassifier < PCatalogEntryClassifier
  end

  # Additional Relationships
  #
  PClassifier.has_one 'super_classifier', PClassifier, :lowerBound => 0

end