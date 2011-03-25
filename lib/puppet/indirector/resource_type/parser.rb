require 'puppet/resource/type'
require 'puppet/indirector/code'
require 'puppet/indirector/resource_type'

class Puppet::Indirector::ResourceType::Parser < Puppet::Indirector::Code
  desc "Return the data-form of a resource type."

  def find(request)
    krt = request.environment.known_resource_types

    # This is a bit ugly.
    [:hostclass, :definition, :node].each do |type|
      # We have to us 'find_<type>' here because it will
      # load any missing types from disk, whereas the plain
      # '<type>' method only returns from memory.
      if r = krt.send("find_#{type}", [""], request.key)
        return r
      end
    end
    nil
  end

  def search(request)
    raise ArgumentError, "Only '*' is acceptable as a search request" unless request.key == "*"
    krt = request.environment.known_resource_types
    # Make sure we've got all of the types loaded.
    krt.loader.import_all
    result = [krt.hostclasses.values, krt.definitions.values, krt.nodes.values].flatten.reject { |t| t.name == "" }
    return nil if result.empty?
    result
  end
end
