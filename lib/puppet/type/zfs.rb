module Puppet
  Type.newtype(:zfs) do
    @doc = "Manage zfs. Create destroy and set properties on zfs instances.

**Autorequires:** If Puppet is managing the zpool at the root of this zfs
instance, the zfs resource will autorequire it. If Puppet is managing any
parent zfs instances, the zfs resource will autorequire them."

    ensurable

    newparam(:name) do
      desc "The full name for this filesystem (including the zpool)."
    end

    newproperty(:aclinherit) do
      desc "The aclinherit property. Valid values are `discard`, `noallow`, `restricted`, `passthrough`, `passthrough-x`."
    end

    newproperty(:aclmode) do
      desc "The aclmode property. Valid values are `discard`, `groupmask`, `passthrough`."
    end

    newproperty(:acltype) do
      desc "The acltype propery. Valid values are 'noacl' and 'posixacl'. Only supported on Linux."
    end

    newproperty(:atime) do
      desc "The atime property. Valid values are `on`, `off`."
    end

    newproperty(:canmount) do
      desc "The canmount property. Valid values are `on`, `off`, `noauto`."
    end

    newproperty(:checksum) do
      desc "The checksum property. Valid values are `on`, `off`, `fletcher2`, `fletcher4`, `sha256`."
    end

    newproperty(:compression) do
      desc "The compression property. Valid values are `on`, `off`, `lzjb`, `gzip`, `gzip-[1-9]`, `zle`."
    end

    newproperty(:copies) do
      desc "The copies property. Valid values are `1`, `2`, `3`."
    end

    newproperty(:dedup) do
      desc "The dedup property. Valid values are `on`, `off`."
    end

    newproperty(:devices) do
      desc "The devices property. Valid values are `on`, `off`."
    end

    newproperty(:exec) do
      desc "The exec property. Valid values are `on`, `off`."
    end

    newproperty(:logbias) do
      desc "The logbias property. Valid values are `latency`, `throughput`."
    end

    newproperty(:mountpoint) do
      desc "The mountpoint property. Valid values are `<path>`, `legacy`, `none`."
    end

    newproperty(:nbmand) do
      desc "The nbmand property. Valid values are `on`, `off`."
    end

    newproperty(:primarycache) do
      desc "The primarycache property. Valid values are `all`, `none`, `metadata`."
    end

    newproperty(:quota) do
      desc "The quota property. Valid values are `<size>`, `none`."
    end

    newproperty(:readonly) do
      desc "The readonly property. Valid values are `on`, `off`."
    end

    newproperty(:recordsize) do
      desc "The recordsize property. Valid values are powers of two between 512 and 128k."
    end

    newproperty(:refquota) do
      desc "The refquota property. Valid values are `<size>`, `none`."
    end

    newproperty(:refreservation) do
      desc "The refreservation property. Valid values are `<size>`, `none`."
    end

    newproperty(:reservation) do
      desc "The reservation property. Valid values are `<size>`, `none`."
    end

    newproperty(:secondarycache) do
      desc "The secondarycache property. Valid values are `all`, `none`, `metadata`."
    end

    newproperty(:setuid) do
      desc "The setuid property. Valid values are `on`, `off`."
    end

    newproperty(:shareiscsi) do
      desc "The shareiscsi property. Valid values are `on`, `off`, `type=<type>`."
    end

    newproperty(:sharenfs) do
      desc "The sharenfs property. Valid values are `on`, `off`, share(1M) options"
    end

    newproperty(:sharesmb) do
      desc "The sharesmb property. Valid values are `on`, `off`, sharemgr(1M) options"
    end

    newproperty(:snapdir) do
      desc "The snapdir property. Valid values are `hidden`, `visible`."
    end

    newproperty(:version) do
      desc "The version property. Valid values are `1`, `2`, `3`, `4`, `current`."
    end

    newproperty(:volsize) do
      desc "The volsize property. Valid values are `<size>`"
    end

    newproperty(:vscan) do
      desc "The vscan property. Valid values are `on`, `off`."
    end

    newproperty(:xattr) do
      desc "The xattr property. Valid values are `on`, `off`."
    end

    newproperty(:zoned) do
      desc "The zoned property. Valid values are `on`, `off`."
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
