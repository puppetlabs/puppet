# A DataAdapter adapts an object with a Hash of data
#
module Puppet::Pops
module Lookup
class DataAdapter < Adaptable::Adapter
  attr_accessor :data

  def self.create_adapter(o)
    new
  end

  def initialize
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'Puppet::DataProviders::DataAdapter',
        'Puppet::DataProviders::DataAdapter is deprecated and will be removed in the next major version of Puppet')
    end
    @data = {}
  end

  def [](name)
    @data[name]
  end

  def has_name?(name)
    @data.has_key? name
  end

  def []=(name, value)
    unless value.is_a?(Hash)
      raise ArgumentError, "Given value must be a Hash, got: #{value.class}."
    end
    @data[name] = value
  end
end
end
end
