require 'puppet'
require 'puppet/rails/lib/init'
require 'puppet/rails/param_name'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Resource < ActiveRecord::Base
    include Puppet::Util::CollectionMerger

    has_many :param_values, :through => :param_names
    has_many :param_names, :dependent => :destroy
    has_many :source_files
    belongs_to :host

    acts_as_taggable

    def [](param)
        return super || parameter(param)
    end

    def parameter(param)
        if pn = param_names.find_by_name(param)
            if pv = pn.param_values.find(:first)
                return pv.value
            else
                return nil
            end
        end
    end

    def parameters
        hash = {}
        self.param_values.find(:all).each do |pvalue|
            pname = pvalue.param_name.name
            hash.store(pname, pvalue.value)
        end
        return hash
    end

    def ref
        "%s[%s]" % [self[:restype], self[:title]]
    end

    # Convert our object to a resource.  Do not retain whether the object
    # is exported, though, since that would cause it to get stripped
    # from the configuration.
    def to_resource(scope)
        hash = self.attributes
        hash["type"] = hash["restype"]
        hash.delete("restype")

        # FIXME At some point, we're going to want to retain this information
        # for logging and auditing.
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

        # Store the ID, so we can check if we're re-collecting the same resource.
        obj.rails_id = self.id

        return obj
    end
end
