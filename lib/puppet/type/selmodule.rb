#
# Simple module for managing SELinux policy modules
#

Puppet::Type.newtype(:selmodule) do
  @doc = "Manages loading and unloading of SELinux policy modules
    on the system.  Requires SELinux support.  See man semodule(8)
    for more information on SELinux policy modules.

    **Autorequires:** If Puppet is managing the file containing this SELinux
    policy module (which is either explicitly specified in the `selmodulepath`
    attribute or will be found at {`selmoduledir`}/{`name`}.pp), the selmodule
    resource will autorequire that file."

  ensurable

  newparam(:name) do
    desc "The name of the SELinux policy to be managed.  You should not
      include the customary trailing .pp extension."
    isnamevar
  end

  newparam(:selmoduledir) do

    desc "The directory to look for the compiled pp module file in.
      Currently defaults to `/usr/share/selinux/targeted`.  If the
      `selmodulepath` attribute is not specified, Puppet will expect to find
      the module in `<selmoduledir>/<name>.pp`, where `name` is the value of the
      `name` parameter."

    defaultto "/usr/share/selinux/targeted"
  end

  newparam(:selmodulepath) do

    desc "The full path to the compiled .pp policy module.  You only need to use
      this if the module file is not in the `selmoduledir` directory."

  end

  newproperty(:syncversion) do

    desc "If set to `true`, the policy will be reloaded if the
    version found in the on-disk file differs from the loaded
    version.  If set to `false` (the default) the only check
    that will be made is if the policy is loaded at all or not."

    newvalue(:true)
    newvalue(:false)
  end

  autorequire(:file) do
    if self[:selmodulepath]
      [self[:selmodulepath]]
    else
      ["#{self[:selmoduledir]}/#{self[:name]}.pp"]
    end
  end
end
