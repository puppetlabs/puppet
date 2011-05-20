module Puppet
  newtype(:zfs) do
    @doc = "Manage zfs. Create destroy and set properties on zfs instances.

**Autorequires:** If Puppet is managing the zpool at the root of this zfs instance, the zfs resource will autorequire it. If Puppet is managing any parent zfs instances, the zfs resource will autorequire them."

    ensurable

    newparam(:name) do
      desc "The full name for this filesystem. (including the zpool)"
    end

    newproperty(:aclinherit) do
      desc "The aclinherit property. Values: discard | noallow | restricted | passthrough | passthrough-x"
    end

    newproperty(:aclmode) do
      desc "The aclmode property. Values: discard | groupmask | passthrough"
    end

    newproperty(:atime) do
      desc "The atime property. Values: on | off"
    end

    newproperty(:canmount) do
      desc "The canmount property. Values: on | off | noauto"
    end

    newproperty(:checksum) do
      desc "The checksum property. Values: on | off | fletcher2 | fletcher4 | sha256"
    end

    newproperty(:compression) do
      desc "The compression property. Values: on | off | lzjb | gzip | gzip-[1-9] | zle"
    end

    newproperty(:copies) do
      desc "The copies property. Values: 1 | 2 | 3"
    end

    newproperty(:devices) do
      desc "The devices property. Values: on | off"
    end

    newproperty(:exec) do
      desc "The exec property. Values: on | off"
    end

    newproperty(:logbias) do
      desc "The logbias property. Values: latency | throughput"
    end

    newproperty(:mountpoint) do
      desc "The mountpoint property. Values: <path> | legacy | none"
    end

    newproperty(:nbmand) do
      desc "The nbmand property. Values: on | off"
    end

    newproperty(:primarycache) do
      desc "The primarycache property. Values: all | none | metadata"
    end

    newproperty(:quota) do
      desc "The quota property. Values: <size> | none"
    end

    newproperty(:readonly) do
      desc "The readonly property. Values: on | off"
    end

    newproperty(:recordsize) do
      desc "The recordsize property. Values: 512 to 128k, power of 2"
    end

    newproperty(:refquota) do
      desc "The refquota property. Values: <size> | none"
    end

    newproperty(:refreservation) do
      desc "The refreservation property. Values: <size> | none"
    end

    newproperty(:reservation) do
      desc "The reservation property. Values: <size> | none"
    end

    newproperty(:secondarycache) do
      desc "The secondarycache property. Values: all | none | metadata"
    end

    newproperty(:setuid) do
      desc "The setuid property. Values: on | off"
    end

    newproperty(:shareiscsi) do
      desc "The shareiscsi property. Values: on | off | type=<type>"
    end

    newproperty(:sharenfs) do
      desc "The sharenfs property. Values: on | off | share(1M) options"
    end

    newproperty(:sharesmb) do
      desc "The sharesmb property. Values: on | off | sharemgr(1M) options"
    end

    newproperty(:snapdir) do
      desc "The snapdir property. Values: hidden | visible"
    end

    newproperty(:version) do
      desc "The version property. Values: 1 | 2 | 3 | 4 | current"
    end

    newproperty(:volsize) do
      desc "The volsize property. Values: <size>"
    end

    newproperty(:vscan) do
      desc "The vscan property. Values: on | off"
    end

    newproperty(:xattr) do
      desc "The xattr property. Values: on | off"
    end

    newproperty(:zoned) do
      desc "The zoned property. Values: on | off"
    end

    autorequire(:zpool) do
      #strip the zpool off the zfs name and autorequire it
      [@parameters[:name].value.split('/')[0]]
    end

    autorequire(:zfs) do
      #slice and dice, we want all the zfs before this one
      names = @parameters[:name].value.split('/')
      names.slice(1..-2).inject([]) { |a,v| a << "#{a.last}/#{v}" }.collect { |fs| names[0] + fs }
    end
  end
end
