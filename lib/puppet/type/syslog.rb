module Puppet
	newtype(:syslog) do
		@doc = "Installs and manages syslog config files for syslogd.
			Facilities and levels when unspecified default to *.
	
			Example
			syslog { logging:
				facility => \"local0\",
				level => *,
				target	=> \"/var/log/local0.log\"
			}

		To allow for multiple targets, pass target as an array."

		ensurable

		newproperty(:facility)
			desc "The facility at which logging happens. See syslog.conf(5) for details"
		end

		newproperty(:level)
			desc "The level at which logging happens"
		end

		newproperty(:target)
			desc "The file or host to which logging happens"
		end
	end
end
