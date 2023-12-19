# frozen_string_literal: true
# included so we can test object types
require_relative '../../puppet'
require_relative '../../puppet/network/format_support'

# A class for handling metrics.  This is currently ridiculously hackish.
class Puppet::Util::Metric
  include Puppet::Util::PsychSupport
  include Puppet::Network::FormatSupport

  attr_accessor :type, :name, :value, :label
  attr_writer :values

  def self.from_data_hash(data)
    metric = allocate
    metric.initialize_from_hash(data)
    metric
  end

  def initialize_from_hash(data)
    @name = data['name']
    @label = data['label'] || self.class.labelize(@name)
    @values = data['values']
  end

  def to_data_hash
    {
      'name' => @name,
      'label' => @label,
      'values' => @values
    }
  end

  # Return a specific value
  def [](name)
    value = @values.find { |v| v[0] == name }
    if value
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
    @values.sort_by { |a| a[1] }
  end

  # Convert a name into a label.
  def self.labelize(name)
    name.to_s.capitalize.tr("_", " ")
  end
end
