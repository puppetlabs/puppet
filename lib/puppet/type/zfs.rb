module Puppet
  newtype(:zfs) do
    @doc = "Manage zfs. Create destroy and set properties on zfs instances.

**Autorequires:** If Puppet is managing the zpool at the root of this zfs instance, the zfs resource will autorequire it. If Puppet is managing any parent zfs instances, the zfs resource will autorequire them."

    ensurable

    newparam(:name) do
      desc "The full name for this filesystem. (including the zpool)"
    end

    newproperty(:mountpoint) do
      desc "The mountpoint property."
    end

    newproperty(:recordsize) do
      desc "The recordsize property."
    end

    newproperty(:aclmode) do
      desc "The aclmode property."
    end

    newproperty(:aclinherit) do
      desc "The aclinherit property."
    end

    newproperty(:primarycache) do
      desc "The primarycache property."
    end

    newproperty(:secondarycache) do
      desc "The secondarycache property."
    end

    newproperty(:compression) do
      desc "The compression property."
    end

    newproperty(:copies) do
      desc "The copies property."
    end

    newproperty(:quota) do
      desc "The quota property."
    end

    newproperty(:reservation) do
      desc "The reservation property."
    end

    newproperty(:sharenfs) do
      desc "The sharenfs property."
    end

    newproperty(:snapdir) do
      desc "The snapdir property."
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
