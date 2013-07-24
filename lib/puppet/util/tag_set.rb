require 'set'

class Puppet::Util::TagSet < Set
  def self.from_yaml(yaml)
    self.new(YAML.load(yaml))
  end

  def to_yaml
    @hash.keys.to_yaml
  end

  def self.from_pson(data)
    self.new(data)
  end

  def to_pson(*args)
    to_a.to_pson
  end

  # this makes puppet serialize it as an array for backwards
  # compatibility
  def to_zaml(z)
    to_a.to_zaml(z)
  end

  def join(*args)
    to_a.join(*args)
  end
end
