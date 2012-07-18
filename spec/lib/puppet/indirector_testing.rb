require 'puppet/indirector'
require 'puppet/util/pson'

class Puppet::IndirectorTesting
  extend Puppet::Indirector
  indirects :indirector_testing

  # We should have some way to identify if we got a valid object back with the
  # current values, no?
  attr_accessor :value
  def initialize(value)
    self.value = value
  end

  PSON.register_document_type('IndirectorTesting',self)
  def self.from_pson(data)
    new(data['value'])
  end

  def to_pson
    {
      'document_type' => 'IndirectorTesting',
      'data'          => { 'value' => value },
      'metadata'      => { 'api_version' => 1 }
    }.to_pson
  end
end
