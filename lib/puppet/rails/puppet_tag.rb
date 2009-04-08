require 'puppet/rails/resource_tag'
class Puppet::Rails::PuppetTag < ActiveRecord::Base
    has_many :resource_tags, :dependent => :destroy
    has_many :resources, :through => :resource_tags

    def self.accumulate_by_name(name)
        @name_cache ||= {}
        if instance = @name_cache[name]
            return instance
        end
        instance = find_or_create_by_name(name)
        @name_cache[name] = instance
        instance
    end
end
