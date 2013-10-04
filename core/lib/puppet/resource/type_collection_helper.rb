require 'puppet/resource/type_collection'

module Puppet::Resource::TypeCollectionHelper
  def known_resource_types
    environment.known_resource_types
  end
end
