# frozen_string_literal: true

require_relative '../../puppet/confine'

class Puppet::Confine::Feature < Puppet::Confine
  def self.summarize(confines)
    confines.collect(&:values).flatten.uniq.find_all { |value| !confines[0].pass?(value) }
  end

  # Is the named feature available?
  def pass?(value)
    Puppet.features.send(value.to_s + "?")
  end

  def message(value)
    "feature #{value} is missing"
  end
end
