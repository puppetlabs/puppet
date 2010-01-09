require 'puppet'

module Puppet::DSL
end

require 'puppet/dsl/resource_type_api'
require 'puppet/dsl/resource_api'

class Object
    include Puppet::DSL::ResourceTypeAPI
end
