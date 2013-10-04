#
# Manages a Vlan on a given router or switch
#

Puppet::Type.newtype(:vlan) do
    @doc = "Manages a VLAN on a router or switch."

    apply_to_device

    ensurable

    newparam(:name) do
      desc "The numeric VLAN ID."
      isnamevar

      newvalues(/^\d+/)
    end

    newproperty(:description) do
      desc "The VLAN's name."
    end

    newparam(:device_url) do
      desc "The URL of the router or switch maintaining this VLAN."
    end
end
