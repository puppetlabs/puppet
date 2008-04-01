class Puppet::Rails::ResourceTag < ActiveRecord::Base
    belongs_to :puppet_tag
    belongs_to :resource

    def to_label
      "#{self.puppet_tag.name}"
    end  
end
