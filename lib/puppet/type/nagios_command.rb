require 'puppet/external/nagios'
require 'puppet/external/nagios/base'

Puppet::Type.newtype(:nagios_command) do
    ensurable

    nagtype = Nagios::Base.type(:command)

    raise "No nagios type" unless nagtype

    newparam(nagtype.namevar, :namevar => true) do
        desc "The name parameter for Nagios type %s" % nagtype.name
    end

    nagtype.parameters.each do |param|
        next if param == nagtype.namevar

        newproperty(param) do
            desc "Nagios configuration file parameter."
        end
    end

    newproperty(:target) do
        desc 'target'

        defaultto do
            resource.class.defaultprovider.default_target
        end
    end
end
