require 'active_record'

class Puppet::Rails::FactValue < ActiveRecord::Base
  belongs_to :fact_name
  belongs_to :host

  def to_label
    "#{self.fact_name.name}"
  end
end
