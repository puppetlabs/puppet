require 'puppet/indirector'

class Puppet::IndirectorTesting
  extend Puppet::Indirector
  indirects :indirector_testing

  # We should have some way to identify if we got a valid object back with the
  # current values, no?
  attr_accessor :value
  alias_method :name, :value
  alias_method :name=, :value=
  def initialize(value)
    self.value = value
  end

  def self.from_binary(raw)
    new(raw)
  end

  def self.from_data_hash(data)
    new(data['value'])
  end

  def to_data_hash
    { 'value' => value }
  end
end
