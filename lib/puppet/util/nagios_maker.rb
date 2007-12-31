require 'puppet/external/nagios'
require 'puppet/external/nagios/base'
require 'puppet/provider/naginator'

module Puppet::Util::NagiosMaker
    # Create a new nagios type, using all of the parameters
    # from the parser.
    def self.create_nagios_type(name)
        name = name.to_sym
        full_name = ("nagios_" + name.to_s).to_sym

        raise(Puppet::DevError, "No nagios type for %s" % name) unless nagtype = Nagios::Base.type(name)

        type = Puppet::Type.newtype(full_name) {}

        type.ensurable

        type.newparam(nagtype.namevar, :namevar => true) do
            desc "The name parameter for Nagios type %s" % nagtype.name
        end

        nagtype.parameters.each do |param|
            next if param == nagtype.namevar

            type.newproperty(param) do
                desc "Nagios configuration file parameter."
            end
        end

        type.newproperty(:target) do
            desc 'target'

            defaultto do
                resource.class.defaultprovider.default_target
            end
        end

        type.provide(:naginator, :parent => Puppet::Provider::Naginator, :default_target => "/etc/nagios/#{full_name.to_s}.cfg") {}
    end
end
