class Puppet::Rails::FactValue < ActiveRecord::Base
    belongs_to :fact_names
end
