module Puppet::Pops::API::Model::Catalog
  # A Catalog Object is abstract and Visitable
  class CatalogObject < RGen::MetamodelBuilder::MMBase
    include Puppet::Pops::API::Visitable 
    abstract
  end

  class Catalog < CatalogObject
    has_attr 'name', String
    contains_many 'resources', CatalogResource, 'catalog'
    # TODO: 
    # the serialized format has 'version', but is that the serialization type version, or version of
    # meta model, or version of puppet? If it is serialization version, it has no place here.
    # TODO: The metamodel should have a version somewhere (probably not available when building it
    # using this simplified internal DSL.
  end

  class Taggable < CatalogObject
    abstract
    has_many_attr 'tags', String
  end
  
  class CatalogResource < Taggable
    has_attr 'file', String
    has_attr 'line', Integer
    has_one  'type', Puppet::Parser2::PuppetType, :lower_bound => 1
   
    # Using a different terminology, as the named properties are not suitable as
    # names for the many to many relationships:
    # followers <-> leaders instead of: before <-> require
    # subscribers <-> notifiers instead of: notify <-> subscribe
    # other edges?
    many_to_many 'subscribers', CatalogResource, 'notifiers'
    many_to_many 'followers', CatalogResource, 'leaders'
  end
  
  class CatalogResourceProperty < CatalogObject
    has_attr 'name', String
    has_many_attr 'value', Object
  end
end