module Puppet
  Type.newtype(:selboolean) do
    @doc = "Manages SELinux booleans on systems with SELinux support.  The supported booleans
      are any of the ones found in `/selinux/booleans/`."

    newparam(:name) do
      desc "The name of the SELinux boolean to be managed."
      isnamevar
    end

    newproperty(:value) do
      desc "Whether the SELinux boolean should be enabled or disabled."
      newvalue(:on)
      newvalue(:off)
    end

    newparam(:persistent) do
      desc "If set true, SELinux booleans will be written to disk and persist across reboots.
        The default is `false`."

      defaultto :false
      newvalues(:true, :false)
    end

  end
end
