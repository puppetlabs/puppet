require 'puppet/resource/type'
require 'puppet/indirector/rest'
require 'puppet/indirector/resource_type'

class Puppet::Indirector::ResourceType::Rest < Puppet::Indirector::REST
  desc "Retrieve resource types via a REST HTTP interface."
end
