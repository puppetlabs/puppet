require 'puppet'
require 'puppet/rails/rails_parameter'

#RailsParameter = Puppet::Rails::RailsParameter
class Puppet::Rails::RailsResource < ActiveRecord::Base
    has_many :rails_parameters, :dependent => :delete_all
    serialize :tags, Array

    belongs_to :host

    # Convert our object to a resource.  Do not retain whether the object
    # is collectable, though, since that would cause it to get stripped
    # from the configuration.
    def to_resource(scope)
        hash = self.attributes
        hash["type"] = hash["restype"]
        hash.delete("restype")
        hash.delete("host_id")
        hash.delete("id")
        hash.each do |p, v|
            hash.delete(p) if v.nil?
        end
        hash[:scope] = scope
        hash[:source] = scope.source
        obj = Puppet::Parser::Resource.new(hash)
        rails_parameters.each do |param|
            obj.set(param.to_resourceparam(scope.source))
        end

        return obj
    end
end

# $Id$
