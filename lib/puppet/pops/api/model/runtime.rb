require 'rgen/metamodel_builder'
require 'puppet/pops/api'
module Puppet; module Pops; module API; module Runtime
  class RuntimeObject < RGen::MetamodelBuilder::MMBase
    include Puppet::Pops::Visitable
    include Puppet::Pops::Adaptable 
    abstract
  end

  class Type < RuntimeObject
    has_attr 'name', String
    has_one 'super_type', Type
    has_one_uni 'model_class', RGen::ECore::EClass
    has_attr 'instance_class', Object, :transient => true
    contains_many_uni 'attributes', Attribute
    contains_many_uni 'invariants', Puppet::Pops::API::Model::Invariant
  end
  
  class Attribute < RuntimeObject
    has_attr 'name', String
    has_one 'data_type', RGen::ECore::EDataType
    
  end
  
  class ResourceType < Type
  end
  
  class TypedObject
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
end; end; end; end