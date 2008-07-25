#
# Simple module for manageing SELinux policy modules
#

Puppet::Type.newtype(:selmodule) do
    @doc = "Enable or disable SELinux policy modules."

    ensurable

    newparam(:name) do
        desc "The name of the SELinux policy to be managed."
        isnamevar
    end

    newparam(:selmoduledir) do

        desc "The directory to look for the compiled pp module file in.
        Currently defaults to /usr/share/selinux/targeted"

        defaultto "/usr/share/selinux/targeted"
    end

    newparam(:selmodulepath) do

        desc "The full path in which to look for the compiled pp
        module file in.  You only need to use this if the module file
        is not in the directory pointed at by selmoduledir."

    end

    newproperty(:syncversion) do

        desc "If set to 'true', the policy will be reloaded if the
        version found in the on-disk file differs from the loaded
        version.  If set to 'false' (the default) the the only check
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

