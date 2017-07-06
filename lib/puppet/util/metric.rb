# included so we can test object types
require 'puppet'
require 'puppet/network/format_support'

# A class for handling metrics.  This is currently ridiculously hackish.
class Puppet::Util::Metric
  include Puppet::Network::FormatSupport

  attr_accessor :type, :name, :value, :label
  attr_writer :values

  def self.from_data_hash(data)
    metric = new(data['name'], data['label'])
    metric.values = data['values']
    metric
  end

  def to_data_hash
    {
      'name' => @name,
      'label' => @label,
      'values' => @values
    }
  end

  def to_pson(*args)
    to_data_hash.to_pson(*args)
  end

  # Return a specific value
  def [](name)
    if value = @values.find { |v| v[0] == name }
      return value[2]
    else
      return 0
    end
  end

  def initialize(name,label = nil)
    @name = name.to_s

    @label = label || self.class.labelize(name)

    @values = []
  end

  def newvalue(name,value,label = nil)
    raise ArgumentError.new("metric name #{name.inspect} is not a string") unless name.is_a? String
    label ||= self.class.labelize(name)
    @values.push [name,label,value]
  end

  def values
    @values.sort { |a, b| a[1] <=> b[1] }
  end

  # Convert a name into a label.
  def self.labelize(name)
    name.to_s.capitalize.gsub("_", " ")
  end
end
