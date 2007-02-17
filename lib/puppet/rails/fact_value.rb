class Puppet::Rails::FactValue < ActiveRecord::Base
    belongs_to :fact_name
end

# $Id: fact_value.rb 1952 2006-12-19 05:47:57Z luke $
