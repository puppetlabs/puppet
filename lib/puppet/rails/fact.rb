class Puppet::Rails::Fact < ActiveRecord::Base
  belongs_to :host
end

