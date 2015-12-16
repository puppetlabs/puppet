#
# Manages an interface on a given router or switch
#

require 'puppet/util/network_device/ipcalc'

Puppet::Type.newtype(:interface) do

    @doc = "This represents a router or switch interface. It is possible to manage
    interface mode (access or trunking, native vlan and encapsulation) and
    switchport characteristics (speed, duplex)."

    apply_to_device

    ensurable do
      defaultvalues

      aliasvalue :shutdown, :absent
      aliasvalue :no_shutdown, :present

      defaultto { :no_shutdown }
    end

    newparam(:name) do
      desc "The interface's name."
    end

    newparam(:device_url) do
      desc "The URL at which the router or switch can be reached."
    end

    newproperty(:description) do
      desc "Interface description."

      defaultto { @resource[:name] }
    end

    newproperty(:speed) do
      desc "Interface speed."
      newvalues(:auto, /^\d+/)
    end

    newproperty(:duplex) do
      desc "Interface duplex."
      newvalues(:auto, :full, :half)
    end

    newproperty(:access_vlan) do
      desc "Interface static access vlan."
      newvalues(/^\d+/)
    end

    newproperty(:native_vlan) do
      desc "Interface native vlan when trunking."
      newvalues(/^\d+/)
    end

    newproperty(:encapsulation) do
      desc "Interface switchport encapsulation."
      newvalues(:none, :dot1q, :isl, :negotiate)
    end

    newproperty(:mode) do
      desc "Interface switchport mode."
      newvalues(:access, :trunk, 'dynamic auto', 'dynamic desirable')
    end

    newproperty(:allowed_trunk_vlans) do
      desc "Allowed list of Vlans that this trunk can forward."
      newvalues(:all, /./)
    end

    newproperty(:etherchannel) do
      desc "Channel group this interface is part of."
      newvalues(/^\d+/)
    end

    newproperty(:ipaddress, :array_matching => :all) do
      include Puppet::Util::NetworkDevice::IPCalc

      desc "IP Address of this interface. Note that it might not be possible to set
      an interface IP address; it depends on the interface type and device type.

      Valid format of ip addresses are:

      * IPV4, like 127.0.0.1
      * IPV4/prefixlength like 127.0.1.1/24
      * IPV6/prefixlength like FE80::21A:2FFF:FE30:ECF0/128
      * an optional suffix for IPV6 addresses from this list: `eui-64`, `link-local`

      It is also possible to supply an array of values.
      "

      validate do |values|
        values = [values] unless values.is_a?(Array)
        values.each do |value|
          self.fail "Invalid interface ip address" unless parse(value.gsub(/\s*(eui-64|link-local)\s*$/,''))
        end
      end

      munge do |value|
        option = value =~ /eui-64|link-local/i ? value.gsub(/^.*?\s*(eui-64|link-local)\s*$/,'\1') : nil
        [parse(value.gsub(/\s*(eui-64|link-local)\s*$/,'')), option].flatten
      end

      def value_to_s(value)
        value = [value] unless value.is_a?(Array)
        value.map{ |v| "#{v[1].to_s}/#{v[0]} #{v[2]}"}.join(",")
      end

      def change_to_s(currentvalue, newvalue)
        currentvalue = value_to_s(currentvalue) if currentvalue != :absent
        newvalue = value_to_s(newvalue)
        super(currentvalue, newvalue)
      end
    end

  def present?(current_values)
    super && current_values[:ensure] != :shutdown
  end
end
