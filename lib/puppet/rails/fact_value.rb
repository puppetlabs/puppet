class Puppet::Rails::FactValue < ActiveRecord::Base
    belongs_to :fact_name
end
