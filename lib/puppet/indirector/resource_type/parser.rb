require 'puppet/resource/type'
require 'puppet/indirector/code'
require 'puppet/indirector/resource_type'

class Puppet::Indirector::ResourceType::Parser < Puppet::Indirector::Code
  desc "Return the data-form of a resource type."

  def find(request)
    krt = request.environment.known_resource_types

    # This is a bit ugly.
    [:hostclass, :definition, :node].each do |type|
      if r = krt.send(type, request.key)
        return r
      end
    end
    nil
  end

  def search(request)
=begin
    @modulepath = set_modulepath(options[:modulepath])
    get_code(@modulepath)[:manifests].collect do |file|
      Puppet[:manifest]=file
      get_resources_of_type(:hostclass)
    end.flatten
=end
    raise ArgumentError, "Only '*' is acceptable as a search request" unless request.key == "*"
    krt = request.environment.known_resource_types
    result = [krt.hostclasses.values, krt.definitions.values, krt.nodes.values].flatten
    return nil if result.empty?
    result
  end
end
