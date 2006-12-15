require 'puppet'
require 'puppet/rails/lib/init'
require 'puppet/rails/param_name'

class Puppet::Rails::Resource < ActiveRecord::Base
    has_many :param_values, :through => :param_names
    has_many :param_names
    has_many :source_files
    belongs_to :hosts

    acts_as_taggable

    def parameters
        hash = {}
        self.param_values.find(:all).each do |pvalue|
            pname = self.param_names.find(:first)
            hash.store(pname.name, pvalue.value)
        end
        return hash
    end

    # Convert our object to a resource.  Do not retain whether the object
    # is collectable, though, since that would cause it to get stripped
    # from the configuration.
    def to_resource(scope)
        hash = self.attributes
        hash["type"] = hash["restype"]
        hash.delete("restype")
        hash.delete("host_id")
        hash.delete("source_file_id")
        hash.delete("id")
        hash.each do |p, v|
            hash.delete(p) if v.nil?
        end
        hash[:scope] = scope
        hash[:source] = scope.source
        obj = Puppet::Parser::Resource.new(hash)
        self.param_names.each do |pname|
            obj.set(pname.to_resourceparam(scope.source))
        end

        return obj
    end
end
