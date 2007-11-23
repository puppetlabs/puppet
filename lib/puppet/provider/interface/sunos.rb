require 'puppet/provider/parsedfile'
require 'erb'

Puppet::Type.type(:interface).provide(:sunos) do
    confine :kernel => "SunOS"

    # Add accessor/getter methods for each property/parameter; these methods
    # modify @property_hash.
    mk_resource_methods

    # Get a list of interface instances.
    def self.instances
		Dir.glob("/etc/hostname.*").collect do |file|
            device = File.basename(file).split(".").pop

            instance = new(:interface => device)
            instance.parse
            instance
        end
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

    def initialize(*args)
        @property_hash = {}
        super
    end

    def create
        self.class.resource_type.validproperties.each do |property|
            if value = resource.should(property)
                @property_hash[property] = value
            end
        end
        @property_hash[:name] = resource.name

        return (@resource.class.name.to_s + "_created").intern
    end

    def destroy
        File.unlink(file_path)
        @property_hash[:ensure] = :absent
    end

    def exists?
        FileTest.exist?(file_path)
    end

    # Where should the file be written out?  Can be overridden by setting
    # :target in the model.
    def file_path
        self.fail("Could not determine interface") unless interface = @property_hash[:interface] || (resource and resource[:interface])
       	return File.join("/etc", "hostname." + interface)
    end

    def flush
        return if self.ensure == :absent
        File.open(file_path, "w") { |f| f.print generate() + "\n" }
    end

    # Turn our record into a line.
    def generate
        ret = []
        if self.interface_type == :alias
            ret << "addif"
        end
        ret << self.name

        if self.ifopts != :absent
            if @property_hash[:ifopts].is_a?(Array)
                ret << @property_hash[:ifopts].join(" ")
            else
                ret << @property_hash[:ifopts]
            end
        end

        if self.onboot and ! [:absent, :false].include?(self.onboot)
            ret << "up"
        end

        return ret.join(" ")
    end

    # Parse our interface file.
    def parse
        (@property_hash = {:ensure => :absent} and return) unless FileTest.exist?(file_path)

        values = File.read(file_path).chomp.split(/\s+/)

        @property_hash[:ensure] = :present
        #@property_hash = {:ensure => :present}

        # Are we the primary interface?
        if values[0] == "addif"
            @property_hash[:interface_type] = :alias
            values.shift
        else
            @property_hash[:interface_type] = :normal
        end

        # Should the interface be up by default?
        if values[-1] == "up"
            @property_hash[:onboot] = :true
            values.pop
        else
            @property_hash[:onboot] = :false
        end

        # Set the interface name.
        @property_hash[:name] = values.shift

        # Handle any interface options
        unless values.empty?
            @property_hash[:ifopts] = values.join(" ")
        end
    end
end
