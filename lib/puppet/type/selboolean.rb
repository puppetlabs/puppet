#
# Simple module for manageing SELinux booleans
#

module Puppet
    newtype(:selboolean) do
        @doc = "Enable or disable SELinux booleans."

        newparam(:name) do
            desc "The name of the SELinux boolean to be managed."
            isnamevar
        end

        newproperty(:value) do
            desc "Whether the the SELinux boolean should be enabled or disabled.  Possible values are ``on`` or ``off``."
            newvalue(:on)
            newvalue(:off)
        end

        newparam(:persistent) do
            desc "If set true, SELinux booleans will be written to disk and persist accross reboots."

            defaultto :false
            newvalues(:true, :false)
        end

    end
end

