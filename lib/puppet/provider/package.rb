class Puppet::Provider::Package < Puppet::Provider
  # Prefetch our package list, yo.
  def self.prefetch(packages)
    instances.each do |prov|
      if pkg = packages[prov.name]
        pkg.provider = prov
      end
    end
  end

  # Clear out the cached values.
  def flush
    @property_hash.clear
  end

  def query
    validate_resource
    query_a_package
  end

  # Look up the current status.
  def properties
    if @property_hash.empty?
      @property_hash = query || {:ensure => :absent}
      @property_hash[:ensure] = :absent if @property_hash.empty?
    end
    @property_hash.dup
  end

  def validate_source(value)
    true
  end

  private

  # @api private
  def validate_resource
    raise(Puppet::ResourceError, "Package providers cannot query a package resource with multiple names (resource->name should not be set to an array).") if resource[:name].kind_of?(Array) && resource[:name].size > 1
  end
end
