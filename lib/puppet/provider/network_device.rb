
# This is the base class of all prefetched network device provider
class Puppet::Provider::NetworkDevice < Puppet::Provider

  def self.lookup(url, name)
    raise "This provider doesn't implement the necessary lookup method"
  end

  def self.prefetch(resources)
    resources.each do |name, resource|
      if result = lookup(resource[:device_url], name)
        result[:ensure] = :present
        resource.provider = new(result)
      else
        resource.provider = new(:ensure => :absent)
      end
    end
  end

  def exists?
    @property_hash[:ensure] != :absent
  end

  def initialize(*args)
    super

    # Make a duplicate, so that we have a copy for comparison
    # at the end.
    @properties = @property_hash.dup
  end

  def create
    @property_hash[:ensure] = :present
    self.class.resource_type.validproperties.each do |property|
      if val = resource.should(property)
        @property_hash[property] = val
      end
    end
  end

  def destroy
    @property_hash[:ensure] = :absent
  end

  def flush
    @property_hash.clear
  end

  def self.instances
  end

  def former_properties
    @properties.dup
  end

  def properties
    @property_hash.dup
  end
end