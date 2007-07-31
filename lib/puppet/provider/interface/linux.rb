require 'puppet/provider/parsedfile'
require 'erb'

Puppet::Type.type(:interface).provide(:linux) do

	confine :kernel => "Linux"

    # Create the setter/gettor methods to match the model.
    mkmodelmethods

    ALIAS_TEMPLATE = ERB.new <<-ALIAS
DEVICE=<%= self.device %>
ONBOOT=<%= self.on_boot %>
BOOTPROTO=none
IPADDR=<%= self.name %>
NETMASK=255.255.255.255
BROADCAST=
ALIAS


    LOOPBACK_TEMPLATE = ERB.new <<-LOOPBACKDUMMY
DEVICE=<%= self.device %>
ONBOOT=<%= self.on_boot %>
BOOTPROTO=static
IPADDR=<%= self.name %>
NETMASK=255.255.255.255
BROADCAST=
LOOPBACKDUMMY

	# maximum number of dummy interfaces
	MAX_DUMMIES = 10

	# maximum number of aliases per interface
	MAX_ALIASES_PER_IFACE = 10

	INTERFACE_DIR = "/etc/sysconfig/network-scripts"

	@@dummies = []
	@@aliases = Hash.new { |hash, key| hash[key] = [] }

	# return the next avaliable dummy interface number, in the case where
	# ifnum is not manually specified

	def self.next_dummy

		MAX_DUMMIES.times do |i|
			unless @@dummies.include?(i.to_s)
				@@dummies << i.to_s
				return i.to_s
			end
		end

	end

	# return the next available alias on a given interface, in the case
	# where ifnum if not manually specified

	def self.next_alias(interface)

		MAX_ALIASES_PER_IFACE.times do |i|
			unless @@aliases[interface].include?(i.to_s)
				@@aliases[interface] << i.to_s
				return i.to_s
			end
		end

	end

	# calculate which dummy interfaces are currently already in
	# use prior to needing to call self.next_dummy later on.

	def self.prefetch

		# parse all of the config files at once

		Dir.glob("%s/ifcfg-*" % INTERFACE_DIR).each do |file|

			record = parse(file)

			# store the existing dummy interfaces

			if record[:interface_type] == :dummy
				@@dummies << record[:ifnum]
			end

			if record[:interface_type] == :alias
				@@aliases[record[:interface]] << record[:ifnum]
			end

		end

	end

    def create

        @model.class.validproperties.each do |property|
            if value = @model.should(property)
                @property_hash[property] = value
            end
        end
        @property_hash[:name] = @model.name

        return (@model.class.name.to_s + "_created").intern
    end

    def destroy
        File.unlink(@model[:target])
    end

    def exists?
        FileTest.exists?(@model[:target])
    end

    # generate the content for the interface file, so this is dependent
    # on whether we are adding an alias to a real interface, or a loopback
    # address (also dummy) on linux. For linux it's quite involved, and we
    # will use an ERB template

	def generate

		# choose which template to use for the interface file, based on
		# the interface type

        case @model.should(:interface_type)
        when :loopback

			return LOOPBACK_TEMPLATE.result(binding)

        when :alias

			return ALIAS_TEMPLATE.result(binding)

		end

	end

    # Where should the file be written out?
	# This defaults to INTERFACE_DIR/ifcfg-<namevar>, but can have a
	# more symbolic name by setting interface_desc in the type. 

    def file_path

		@model[:interface_desc] ||= @model[:name]
       	return File.join(INTERFACE_DIR, "ifcfg-" + @model[:interface_desc])

    end

	# create the device name, so this based on the IP, and interface + type
	def device

		case @model.should(:interface_type)
		when :loopback

			@property_hash[:ifnum] ||= self.class.next_dummy
        	return "dummy" + @property_hash[:ifnum]

		when :alias

			@property_hash[:ifnum] ||= self.class.next_alias(@model[:interface])
        	return @model[:interface] + ":" + @property_hash[:ifnum]

		end

    end

	# whether the device is to be brought up on boot or not. converts
	# the true / false of the type, into yes / no values respectively
	# writing out the ifcfg-* files

	def on_boot

		case @property_hash[:onboot].to_s
		when "true"
			return "yes"
		when "false"
			return "no"
		else
			return "neither"
		end

	end


    # Write the new file out.
    def flush
        # Don't flush to disk if we're removing the config.
        return if @model.should(:ensure) == :absent

        @property_hash.each do |name, val|
            if val == :absent
                raise ArgumentError, "Propety %s must be provided" % val
            end
        end

        File.open(@model[:target], "w") do |f|
            f.puts generate()
        end
    end

    # base the ifnum, for dummy / loopback interface in linux
    # on the last octect of the IP address

    # Parse the existing file.
    def self.parse(file)

        opts = {}
        return opts unless FileTest.exists?(file)

        File.open(file) do |f|
            f.readlines.each do |line|
                if line =~ /^(\w+)=(.+)$/
                    opts[$1.downcase.intern] = $2
                end
            end
        end

        # figure out the "real" device information

        case opts[:device]
        when /:/:

            if opts[:device].include?(":")
                opts[:interface], opts[:ifnum] = opts[:device].split(":")
            end

            opts[:interface_type] = :alias

        when /^dummy/:

            opts[:interface_type] = :loopback

			opts[:interface] = "dummy"

			# take the number of the dummy interface, as this is used
			# when working out whether to call next_dummy when dynamically
			# creating these

			opts[:ifnum] = opts[:device].sub("dummy",'')

			@@dummies << opts[:ifnum].to_s

        else

			opts[:interface_type] = :normal
			opts[:interface] = opts[:device]

        end

		# translate whether we come up on boot to true/false

		case opts[:onboot].downcase
		when "yes":
			opts[:onboot] = :true
		when "no":
			opts[:onboot] = :false
		else
			# this case should never happen, but just in case
			opts[:onboot] = false
		end


        # Remove any attributes we don't want.  These would be
        # pretty easy to support.
        [:bootproto, :broadcast, :netmask, :device].each do |opt|
            if opts.include?(opt)
                opts.delete(opt)
            end
        end

        if opts.include?(:ipaddr)
            opts[:name] = opts[:ipaddr]
            opts.delete(:ipaddr)
        end

        return opts

    end

    def prefetch
        @property_hash = self.class.parse(@model[:target])
    end
end

# $Id$
