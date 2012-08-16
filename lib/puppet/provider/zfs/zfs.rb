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
    if zfs(:list).split("\n").detect { |line| line.split("\s")[0] == @resource[:name] }
      true
    else
      false
    end
  end

  [:aclinherit, :aclmode, :atime, :canmount, :checksum,
   :compression, :copies, :dedup, :devices, :exec, :logbias,
   :mountpoint, :nbmand,  :primarycache, :quota, :readonly,
   :recordsize, :refquota, :refreservation, :reservation,
   :secondarycache, :setuid, :shareiscsi, :sharenfs, :sharesmb,
   :snapdir, :version, :volsize, :vscan, :xattr, :zoned].each do |field|
    define_method(field) do
      zfs(:get, "-H", "-o", "value", field, @resource[:name]).strip
    end

    define_method(field.to_s + "=") do |should|
      zfs(:set, "#{field}=#{should}", @resource[:name])
    end
  end

end

