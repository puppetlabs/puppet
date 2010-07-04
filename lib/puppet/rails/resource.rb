require 'puppet'
require 'puppet/rails/param_name'
require 'puppet/rails/param_value'
require 'puppet/rails/puppet_tag'
require 'puppet/rails/benchmark'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Resource < ActiveRecord::Base
    include Puppet::Util::CollectionMerger
    include Puppet::Util::ReferenceSerializer
    include Puppet::Rails::Benchmark

    has_many :param_values, :dependent => :destroy, :class_name => "Puppet::Rails::ParamValue"
    has_many :param_names, :through => :param_values, :class_name => "Puppet::Rails::ParamName"

    has_many :resource_tags, :dependent => :destroy, :class_name => "Puppet::Rails::ResourceTag"
    has_many :puppet_tags, :through => :resource_tags, :class_name => "Puppet::Rails::PuppetTag"

    belongs_to :source_file
    belongs_to :host

    @tags = {}
    def self.tags
        @tags
    end

    # Determine the basic details on the resource.
    def self.rails_resource_initial_args(resource)
        result = [:type, :title, :line].inject({}) do |hash, param|
            # 'type' isn't a valid column name, so we have to use another name.
            to = (param == :type) ? :restype : param
            if value = resource.send(param)
                hash[to] = value
            end
            hash
        end

        # We always want a value here, regardless of what the resource has,
        # so we break it out separately.
        result[:exported] = resource.exported || false

        result
    end

    def add_resource_tag(tag)
        pt = Puppet::Rails::PuppetTag.accumulate_by_name(tag)
        resource_tags.build(:puppet_tag => pt)
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

    def params_list
        @params_list ||= []
    end

    def params_list=(params)
        @params_list = params
    end

    def add_param_to_list(param)
        params_list << param
    end

    def tags_list
        @tags_list ||= []
    end

    def tags_list=(tags)
        @tags_list = tags
    end

    def add_tag_to_list(tag)
        tags_list << tag
    end

    def [](param)
        return super || parameter(param)
    end

    # Make sure this resource is equivalent to the provided Parser resource.
    def merge_parser_resource(resource)
        accumulate_benchmark("Individual resource merger", :attributes) { merge_attributes(resource) }
        accumulate_benchmark("Individual resource merger", :parameters) { merge_parameters(resource) }
        accumulate_benchmark("Individual resource merger", :tags) { merge_tags(resource) }
        save()
    end

    def merge_attributes(resource)
        args = self.class.rails_resource_initial_args(resource)
        args.each do |param, value|
            unless resource[param] == value
                self[param] = value
            end
        end

        # Handle file specially
        if (resource.file and  (!resource.file or self.file != resource.file))
            self.file = resource.file
        end
    end

    def merge_parameters(resource)
        catalog_params = {}
        resource.each do |param, value|
            catalog_params[param.to_s] = value
        end

        db_params = {}

        deletions = []
        params_list.each do |value|
            # First remove any parameters our catalog resource doesn't have at all.
            deletions << value['id'] and next unless catalog_params.include?(value['name'])

            # Now store them for later testing.
            db_params[value['name']] ||= []
            db_params[value['name']] << value
        end

        # Now get rid of any parameters whose value list is different.
        # This might be extra work in cases where an array has added or lost
        # a single value, but in the most common case (a single value has changed)
        # this makes sense.
        db_params.each do |name, value_hashes|
            values = value_hashes.collect { |v| v['value'] }

            unless value_compare(catalog_params[name], values)
                value_hashes.each { |v| deletions << v['id'] }
            end
        end

        # Perform our deletions.
        Puppet::Rails::ParamValue.delete(deletions) unless deletions.empty?

        # Lastly, add any new parameters.
        catalog_params.each do |name, value|
            next if db_params.include?(name) && ! db_params[name].find{ |val| deletions.include?( val["id"] ) }
            values = value.is_a?(Array) ? value : [value]

            values.each do |v|
                param_values.build(:value => serialize_value(v), :line => resource.line, :param_name => Puppet::Rails::ParamName.accumulate_by_name(name))
            end
        end
    end

    # Make sure the tag list is correct.
    def merge_tags(resource)
        in_db = []
        deletions = []
        resource_tags = resource.tags
        tags_list.each do |tag|
            deletions << tag['id'] and next unless resource_tags.include?(tag['name'])
            in_db << tag['name']
        end
        Puppet::Rails::ResourceTag.delete(deletions) unless deletions.empty?

        (resource_tags - in_db).each do |tag|
            add_resource_tag(tag)
        end
    end

    def value_compare(v,db_value)
        v = [v] unless v.is_a?(Array)

        v == db_value
    end

    def name
        ref()
    end

    def parameter(param)
        if pn = param_names.find_by_name(param)
            if pv = param_values.find(:first, :conditions => [ 'param_name_id = ?', pn])
                return pv.value
            else
                return nil
            end
        end
    end

    def ref(dummy_argument=:work_arround_for_ruby_GC_bug)
        "%s[%s]" % [self[:restype].split("::").collect { |s| s.capitalize }.join("::"), self.title.to_s]
    end

    # Returns a hash of parameter names and values, no ActiveRecord instances.
    def to_hash
        Puppet::Rails::ParamValue.find_all_params_from_resource(self).inject({}) do |hash, value|
            hash[value['name']] ||= []
            hash[value['name']] << value.value
            hash
        end
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
