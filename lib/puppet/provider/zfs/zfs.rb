Puppet::Type.type(:zfs).provide(:zfs) do
  desc "Provider for zfs."

  commands :zfs => 'zfs'

  def self.instances
    zfs(:list, '-H').split("\n").collect do |line|
      name,used,avail,refer,mountpoint = line.split(/\s+/)
      new({:name => name, :ensure => :present})
    end
  end

  def add_properties
    properties = []
    Puppet::Type.type(:zfs).validproperties.each do |property|
      next if property == :ensure
      if value = @resource[property] and value != ""
        properties << "-o" << "#{property}=#{value}"
      end
    end
    properties
  end

  def create
    zfs *([:create] + add_properties + [@resource[:name]])
  end

  def destroy
    zfs(:destroy, @resource[:name])
  end

  def exists?
    begin
      zfs(:list, @resource[:name])
      true
    rescue Puppet::ExecutionFailure
      false
    end
  end

  PARAMETER_UNSET_OR_NOT_AVAILABLE = '-'

  # https://docs.oracle.com/cd/E19963-01/html/821-1448/gbscy.html
  # shareiscsi (added in build 120) was removed from S11 build 136
  # aclmode was removed from S11 in build 139 but it may have been added back
  # http://webcache.googleusercontent.com/search?q=cache:-p74K0DVsdwJ:developers.slashdot.org/story/11/11/09/2343258/solaris-11-released+&cd=13
  [:aclmode, :shareiscsi].each do |field|
    # The zfs commands use the property value '-' to indicate that the
    # property is not set. We make use of this value to indicate that the
    # property is not set since it is not available. Conversely, if these
    # properties are attempted to be unset, and resulted in an error, our
    # best bet is to catch the exception and continue.
    define_method(field) do
      begin
        zfs(:get, "-H", "-o", "value", field, @resource[:name]).strip
      rescue
        PARAMETER_UNSET_OR_NOT_AVAILABLE
      end
    end
    define_method(field.to_s + "=") do |should|
      begin
        zfs(:set, "#{field}=#{should}", @resource[:name])
      rescue
      end
    end
  end

  [:aclinherit, :atime, :canmount, :checksum,
   :compression, :copies, :dedup, :devices, :exec, :logbias,
   :mountpoint, :nbmand,  :primarycache, :quota, :readonly,
   :recordsize, :refquota, :refreservation, :reservation,
   :secondarycache, :setuid, :sharenfs, :sharesmb,
   :snapdir, :version, :volsize, :vscan, :xattr, :zoned].each do |field|
    define_method(field) do
      zfs(:get, "-H", "-o", "value", field, @resource[:name]).strip
    end

    define_method(field.to_s + "=") do |should|
      zfs(:set, "#{field}=#{should}", @resource[:name])
    end
  end

end

