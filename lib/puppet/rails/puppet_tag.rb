require 'puppet/rails/resource_tag'
require 'puppet/util/rails/cache_accumulator'

class Puppet::Rails::PuppetTag < ActiveRecord::Base
    has_many :resource_tags, :dependent => :destroy
    has_many :resources, :through => :resource_tags

    include Puppet::Util::CacheAccumulator
    accumulates :name
end
