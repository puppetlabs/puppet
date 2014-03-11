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

  def self.from_pson(data)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(data)
  end

  def to_data_hash
    to_a
  end

  def to_pson(*args)
    to_data_hash.to_pson
  end

  # this makes puppet serialize it as an array for backwards
  # compatibility
  def to_zaml(z)
    to_data_hash.to_zaml(z)
  end

  def join(*args)
    to_a.join(*args)
  end
end
