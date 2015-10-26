# A DataAdapter adapts an object with a Hash of data
#
class Puppet::DataProviders::DataAdapter < Puppet::Pops::Adaptable::Adapter
  include Puppet::Plugins::DataProviders

  attr_accessor :data

  def self.create_adapter(o)
    new
  end

  def initialize
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
