require 'puppet/provider/parsedfile'

# The default target
# We should be able to override this by setting it explicitly in Facter
case Facter.value(:syslogconf)
when nil:
	syslogconf = "/etc/syslog.conf"
else
	syslogconf = Facter.value(:syslogconf)
end

Puppet::Type.type(syslog).provide(:parsed,
	:parent => Puppet::Provider::ParsedFile,
	:default_target => syslogconf,
	:filetype => :flat
) do
text_line :comment, :match => /^#/
text_line :blank, :match => /^\s+/

record_line :parsed, :fields => %w{source target},
	:post_parse => proc { |hash|
		if hash[:source] =~ /;/
			sources = hash[:source].split(";");
			sources.each { |level|
				if level[:facility] =~ /\./
					names = level[:facility].split("\.")
					hash[:facility] = names.shift
					hash[:priority] = names
				end
			}
		end
	}
	:pre_gen => proc { |hash|
		if hash[:alias]
			names = [hash[:name], hash[:alias]].flatten
			hash[:name] = [hash[:name], hash[:alias]].flatten.join(",")
			hash.delete(:alias)
		end
	}
end   
