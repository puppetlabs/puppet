require 'rgen/metamodel_builder'

# TODO: Fix these in a biff.rb where all modules and requirements are organized
module Puppet::Biff
end
module Puppet::Biff::Model
end

module Puppet::Biff::Model::Catalog
  extend RGen::MetamodelBuilder::ModuleExtension

  # A base class for modeled objects that makes them Visitable, and Adaptable.
  #
  class CatalogObject < RGen::MetamodelBuilder::MMBase
    include Puppet::Pops::Visitable
    include Puppet::Pops::Adaptable
    include Puppet::Pops::Containment
    abstract
  end

  # Holds an URI fragment to a source location
  class Location < CatalogObject
    has_attr 'source_fragment', String, :lowerBound => 1
  end

  # A container of resources
  class ResourceContainer < CatalogObject
    abtract
  end

  # An abstract resource (derived classes define kind)
  #
  class AbstractResource < ResourceContainer
    has_many_attr 'tags', String
    has_attr 'origin', ResourceOrigin, :lowerBound => 1, :defaultValueLiteral => "here"
    contains_one_uni 'created_at', Location, :lowerBound => 0
    contains_one_uni 'imported_at', Location, :lowerBound => 0
    contains_one_uni 'realized_at', Location, :lowerBound => 0
    abstract
  end

  class AbstractResourceReference < AbstractResource
    contains_one_uni 'resource_reference', Puppet::Pops::Types::PResourceType, :lowerBound => 1
    abstract
  end

  # A placeholder resource that must be resolved before the catalog is valid
  #
  class UnresolvedResource < AbstractResourceReference
  end

  # A resource that may be added to a plan, and do actual work if the referenced resource is part
  # of the plan, else represents a no-op
  #
  class OptionalResource < AbstractResourceReference
  end

  ResourceOrigin = RGen::MetamodelBuilder::DataTypes::Enum.new([:here, :imported, :here_exported, :here_virtual ])

  class Resource < AbstractResource
    has_attr 'title', String
    has_attr 'realized', Boolean
    has_many_attr 'aliases', String, :lowerBound => 0

    # TODO: This should be abstract when it is possible to create derived types
  end

  class ProxyResource < AbstractResource
  end

  class SourceReference < CatalogObject
    has_attr 'source_uri', String
  end

  class Relation < CatalogObject
    # A ~> or <~ type of relationship
    has_attr 'notification', Boolean, :defaultValueLiteral => "false"

    # The source has an arrow pointing to the left - the semantics of
    # followers and leaders does not change because of this.
    #
    has_attr 'right2left', Boolean, :defaultValueLiteral => "false"
    contains_one_uni 'location', Location, :lowerBound => 0
  end

  # A CatalogSection is basically a "full catalog", but multiple of them may be combined into one Catalog
  #
  class CatalogSection < ResourceContainer
    has_attr 'name', String
    contains_many_uni 'sources', SourceReference
    contains_many_uni 'relations', Relation, :lowerBound => 0
  end

  # The top level container in a "catalog"
  #
  class Catalog < CatalogObject
    contains_many_uni 'sections', CatalogSection, :lowerBound => 0
  end

  # Additional Relationships
  #
  Location.has_one 'source', SourceReference
  Resource.one_to_many 'proxy_resources', ProxyResource, 'real_resource'
  ResourceContainer.contains_many 'resources', AbstractResource, 'container', :lowerBound => 0
  AbstractResource.one_to_many 'followers', Relation, 'leader', :lowerBound => 0
  AbstractResource.one_to_many 'leaders', Relation, 'follower', :lowerBound => 0
end
