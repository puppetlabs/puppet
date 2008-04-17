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
        pt = Puppet::Rails::PuppetTag.find_or_create_by_name(tag, :include => :puppet_tag)
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
    def get_params_hash(values = nil)
        values ||= param_values.find(:all, :include => :param_name)
        values.inject({}) do | hash, value |
            hash[value.param_name.name] ||= []
            hash[value.param_name.name] << value
            hash
        end
    end
    
    def get_tag_hash(tags = nil)
        tags ||= resource_tags.find(:all, :include => :puppet_tag)
        return tags.inject({}) do |hash, tag|
            # We have to store the tag object, not just the tag name.
            hash[tag.puppet_tag.name] = tag
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
        result = get_params_hash
        result.each do |param, value|
            if value.is_a?(Array)
                result[param] = value.collect { |v| v.value }
            else
                result[param] = value.value
            end
        end
        result
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
        hash.delete("created_at")
        hash.delete("id")
        hash.each do |p, v|
            hash.delete(p) if v.nil?
        end
        hash[:scope] = scope
        hash[:source] = scope.source
        hash[:params] = []
        names = []
        self.param_names.each do |pname|
            # We can get the same name multiple times because of how the
            # db layout works.
            next if names.include?(pname.name)
            names << pname.name
            hash[:params] << pname.to_resourceparam(self, scope.source)
        end
        obj = Puppet::Parser::Resource.new(hash)

        # Store the ID, so we can check if we're re-collecting the same resource.
        obj.rails_id = self.id

        return obj
    end
end
