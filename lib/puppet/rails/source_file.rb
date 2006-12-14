class Puppet::Rails::SourceFile < ActiveRecord::Base
    has_many :hosts, :puppet_classes, :resources
end
