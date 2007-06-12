class Puppet::Rails::ResourceTag < ActiveRecord::Base
    belongs_to :puppet_tag
    belongs_to :resource
end
