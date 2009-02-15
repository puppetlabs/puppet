require 'puppet'
require 'puppet/rails/param_name'
require 'puppet/rails/param_value'
require 'puppet/rails/puppet_tag'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Resource < ActiveRecord::Base
    include Puppet::Util::CollectionMerger
    include Puppet::Util::ReferenceSerializer

    has_many :param_values, :dependent => :destroy, :class_name => "Puppet::Rails::ParamValue"
    has_many :param_names, :through => :param_values, :class_name => "Puppet::Rails::ParamName"

    has_many :resource_tags, :dependent => :destroy, :class_name => "Puppet::Rails::ResourceTag"
    has_many :puppet_tags, :through => :resource_tags, :class_name => "Puppet::Rails::PuppetTag"

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

    def title
        unserialize_value(self[:title])
    end

    def add_param_to_hash(param)
        @params_hash ||= []
        @params_hash << param
    end

    def add_tag_to_hash(tag)
        @tags_hash ||= []
        @tags_hash << tag
    end

    def params_hash=(hash)
        @params_hash = hash
    end

    def tags_hash=(hash)
        @tags_hash = hash
    end

    # returns a hash of param_names.name => [param_values]
    def get_params_hash(values = nil)
        values ||= @params_hash || Puppet::Rails::ParamValue.find_all_params_from_resource(self)
        if values.size == 0
            return {}
        end
        values.inject({}) do |hash, value|
            hash[value['name']] ||= []
            hash[value['name']] << value
            hash
        end
    end

    def get_tag_hash(tags = nil)
        tags ||= @tags_hash || Puppet::Rails::ResourceTag.find_all_tags_from_resource(self)
        return tags.inject({}) do |hash, tag|
            # We have to store the tag object, not just the tag name.
            hash[tag['name']] = tag
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
                result[param] = value.collect { |v| v['value'] }
            else
                result[param] = value.value
            end
        end
        result
    end

    def ref
        "%s[%s]" % [self[:restype].split("::").collect { |s| s.capitalize }.join("::"), self.title.to_s]
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
