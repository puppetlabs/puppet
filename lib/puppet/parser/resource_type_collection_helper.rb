require 'puppet/parser/resource_type_collection'

module Puppet::Parser::ResourceTypeCollectionHelper
    def known_resource_types
        environment.known_resource_types
    end
end
