require 'puppet'
require 'puppet/rails/external/tagging/init'
require 'puppet/rails/param'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Resource < ActiveRecord::Base
    include Puppet::Util::CollectionMerger

    has_many :params, :dependent => :destroy
    belongs_to :source_file
    belongs_to :host

    acts_as_taggable

    Puppet::Type.eachtype do |type|
        klass = Class.new(Puppet::Rails::Resource)
        Object.const_set("Puppet%s" % type.name.to_s.capitalize, klass)
    end
    
    def tags=(tags)
        tags.each do |tag|   
            self.tag_with tag
        end
    end

    def file=(file)
       self.source_file = Puppet::Rails::SourceFile.new(:filename => file)
    end

    def [](param)
        return super || parameter(param)
    end

    def parameter(param)
        if p = params.find_by_name(param)
            return p.value
        end
    end

    def parameters
        hash = {}
        self.params.find(:all).each do |p|
            hash.store(p.name, p.value)
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
        hash.delete("updated_at")
        hash.delete("source_file_id")
        hash.delete("id")
        hash.each do |p, v|
            hash.delete(p) if v.nil?
        end
        hash[:scope] = scope
        hash[:source] = scope.source
        obj = Puppet::Parser::Resource.new(hash)
        self.params.each do |p|
            obj.set(p.to_resourceparam(scope.source))
        end

        # Store the ID, so we can check if we're re-collecting the same resource.
        obj.rails_id = self.id

        return obj
    end
end

# $Id$
