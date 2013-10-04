require 'active_record'
require 'puppet/rails'
require 'puppet/rails/fact_value'

class Puppet::Rails::FactName < ActiveRecord::Base
  has_many :fact_values, :dependent => :destroy
end
