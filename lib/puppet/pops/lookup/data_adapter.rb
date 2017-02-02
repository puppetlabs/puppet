module Puppet::Pops
module Lookup
# A class that adapts a Hash
# @api private
class DataAdapter < Adaptable::Adapter
  def self.create_adapter(o)
    new
  end

  def initialize
    @data = {}
  end

  def [](name)
    @data[name]
  end

  def include?(name)
    @data.include? name
  end

  def []=(name, value)
    @data[name] = value
  end
end
end
end
