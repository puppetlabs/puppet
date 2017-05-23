require 'set'
require 'puppet/network/format_support'

class Puppet::Util::TagSet < Set
  include Puppet::Network::FormatSupport

  def self.from_yaml(yaml)
    self.new(YAML.load(yaml))
  end

  def to_yaml
    @hash.keys.to_yaml
  end

  def self.from_data_hash(data)
    self.new(data)
  end

  # TODO: A method named #to_data_hash should not return an array
  def to_data_hash
    to_a
  end

  def join(*args)
    to_a.join(*args)
  end
end
