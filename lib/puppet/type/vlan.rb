#
# Manages a Vlan on a given router or switch
#

Puppet::Type.newtype(:vlan) do
    @doc = "This represents a router or switch vlan."

    apply_to_device

    ensurable

    newparam(:name) do
      desc "Vlan id. It must be a number"
      isnamevar

      newvalues(/^\d+/)
    end

    newproperty(:description) do
      desc "Vlan name"
    end

    newparam(:device_url) do
      desc "Url to connect to a router or switch."
    end
end