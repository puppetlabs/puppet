require 'puppet'
require 'puppet/rails/param_name'
require 'puppet/rails/puppet_tag'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Resource < ActiveRecord::Base
    include Puppet::Util::CollectionMerger

    has_many :param_values, :dependent => :destroy
    has_many :param_names, :through => :param_values

    has_many :resource_tags, :dependent => :destroy
    has_many :puppet_tags, :through => :resource_tags
    
    belongs_to :source_file
    belongs_to :host

    def add_resource_tag(tag)
        pt = Puppet::Rails::PuppetTag.find_or_create_by_name(tag)
        resource_tags.create(:puppet_tag => pt)
    end

    def file
        if f = self.source_file
            return f.filename
        else
            return nil
        end
    end

    def file=(file)
        self.source_file = Puppet::Rails::SourceFile.find_or_create_by_filename(file)
    end

    # returns a hash of param_names.name => [param_values]
    def get_params_hash
        param_values = self.param_values.find(:all, :include => :param_name)
        return param_values.inject({}) do | hash, value |
            hash[value.param_name.name] ||= []
            hash[value.param_name.name] << value
            hash
        end
    end
    
    def get_tag_hash
        tags = self.resource_tags.find(:all, :include => :puppet_tag)
        return tags.inject({}) do |hash, tag|
            hash[tag.puppet_tag.name] = tag.puppet_tag.name
            hash
        end
    end

    def [](param)
        return super || parameter(param)
    end

    def name
        ref()
    end

    def parameter(param)
        if pn = param_names.find_by_name(param)
            if pv = param_values.find(:first, :conditions => [ 'param_name_id = ?', pn]                                                            )
                return pv.value
            else
                return nil
            end
        end
    end

    def parameters
        return self.param_values.find(:all,
                      :include => :param_name).inject({}) do |hash, pvalue|
            hash[pvalue.param_name.name] ||= []
            hash[pvalue.param_name.name] << pvalue.value 
           hash
        end
    end

    def ref
        "%s[%s]" % [self[:restype].capitalize, self[:title]]
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

        self.param_names.each do |pname|
            obj.set(pname.to_resourceparam(self, scope.source))
        end

        # Store the ID, so we can check if we're re-collecting the same resource.
        obj.rails_id = self.id

        return obj
    end
end

# $Id$
