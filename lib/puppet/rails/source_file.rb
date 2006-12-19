class Puppet::Rails::SourceFile < ActiveRecord::Base
    has_one :host
    has_one :puppet_class
    has_one :resource
end
