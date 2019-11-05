module Puppet
  Type.newtype(:selboolean) do
    @doc = "Manages SELinux booleans on systems with SELinux support.  The supported booleans
      are any of the ones found in `/selinux/booleans/`."

    newparam(:name) do
      desc "The name of the SELinux boolean to be managed."
      isnamevar
    end

    newproperty(:value) do
      value_doc = 'Valid values are: "on"/"true"/"off"/"false"'
      desc <<-EOT
        Whether the SELinux boolean should be enabled or disabled.
        #{value_doc}
      EOT

      newvalues(:on, :off, :true, :false)
      munge do |value|
        case value
        when true, :true, 'true', :on, 'on'
          :on
        when false, :false, 'false', :off, 'off'
          :off
        else
          raise ArgumentError, _("Invalid value %{value}. %{doc}") % { value: value.inspect, doc: value_doc}
        end
      end
    end

    newparam(:persistent) do
      desc "If set to true, SELinux booleans will be written to disk and persist across
        reboots."

      defaultto :false
      newvalues(:true, :false)
    end

  end
end
