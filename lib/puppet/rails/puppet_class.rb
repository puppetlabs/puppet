class Puppet::Rails::PuppetClass < ActiveRecord::Base
    has_many :resources
    has_many :source_files
    has_many :hosts
end

