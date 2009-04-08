require 'puppet/util/rails/collection_merger'
require 'puppet/rails/param_value'

class Puppet::Rails::ParamName < ActiveRecord::Base
    include Puppet::Util::CollectionMerger
    has_many :param_values, :dependent => :destroy 

    def self.accumulate_by_name(name)
        @name_cache ||= {}
        if instance = @name_cache[name]
            return instance
        end
        instance = find_or_create_by_name(name)
        @name_cache[name] = instance
        instance
    end

    def to_resourceparam(resource, source)
        hash = {}
        hash[:name] = self.name.to_sym
        hash[:source] = source
        hash[:value] = resource.param_values.find(:all, :conditions => [ "param_name_id = ?", self.id]).collect { |v| v.value }
        if hash[:value].length == 1
            hash[:value] = hash[:value].shift
        elsif hash[:value].empty?
            hash[:value] = nil
        end
        Puppet::Parser::Resource::Param.new hash
    end
end

