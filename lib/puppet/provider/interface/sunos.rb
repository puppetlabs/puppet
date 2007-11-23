require 'puppet/provider/parsedfile'
require 'erb'

Puppet::Type.type(:interface).provide(:sunos,
	:default_target => "/etc/hostname.lo0",
	:parent => Puppet::Provider::ParsedFile,
	:filetype => :flat
) do
	
    confine :kernel => "SunOS"

    # Two types of lines:
    #   the first line does not start with 'addif'
    #   the rest do
	record_line :sunos, :fields => %w{interface_type name ifopts onboot}, :rts => true, :absent => "", :block_eval => :instance do
        # Parse our interface line
        def process(line)
            details = {:ensure => :present}

            values = line.split(/\s+/)

            # Are we the primary interface?
            if values[0] == "addif"
                details[:interface_type] = :alias
                values.shift
            else
                details[:interface_type] = :normal
            end

            # Should the interface be up by default?
            if values[-1] == "up"
                details[:onboot] = :true
                values.pop
            else
                details[:onboot] = :false
            end

            # Set the interface name.
            details[:name] = values.shift

            # Handle any interface options
            unless values.empty?
                details[:ifopts] = values.join(" ")
            end

            return details
        end

        # Turn our record into a line.
        def to_line(details)
            ret = []
            if details[:interface_type] != :normal
                ret << "addif"
            end
            ret << details[:name]

            if details[:ifopts] and details[:ifopts] != :absent
                if details[:ifopts].is_a?(Array)
                    ret << details[:ifopts].join(" ")
                else
                    ret << details[:ifopts]
                end
            end

            if details[:onboot] and details[:onboot] != :false
                ret << "up"
            end

            return ret.join(" ")
        end
    end

	def self.header
		# over-write the default puppet behaviour of adding a header
		# because on further investigation this breaks the solaris
		# init scripts
		%{}
	end

    # Get a list of interface instances.
    def self.instances
		Dir.glob("/etc/hostname.*").collect do |file|
            # We really only expect one record from each file
            parse(file).shift
        end.collect { |record| new(record) }
    end

	def self.match(hash)
		# see if we can match the has against an existing object
		if model.find { |obj| obj.value(:name) == hash[:name] }
			return obj
        else
            return false
		end	
	end

    # Prefetch our interface list, yo.
    def self.prefetch(resources)
        instances.each do |prov|
            if resource = resources[prov.name]
                resource.provider = prov
            end
        end
    end

    # Where should the file be written out?  Can be overridden by setting
    # :target in the model.
    def file_path
        unless resource[:interface]
            raise ArgumentError, "You must provide the interface name on Solaris"
        end
       	return File.join("/etc", "hostname." + resource[:interface])
    end
end

