class Puppet::IndirectorProxy
  class ProxyId
    attr_accessor :name
    def initialize(name)
      self.name = name
    end
  end

  # We should have some way to identify if we got a valid object back with the
  # current values, no?
  attr_accessor :value, :proxyname
  alias_method :name, :value
  alias_method :name=, :value=
  def initialize(value, proxyname)
    self.value = value
    self.proxyname = proxyname
  end

  def self.indirection
    ProxyId.new("file_metadata")
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
