require 'puppet/provider/parsedfile'
require 'erb'

Puppet::Type.type(:interface).provide(:redhat) do
    desc "Manage network interfaces on Red Hat operating systems.  This provider
        parses and generates configuration files in ``/etc/sysconfig/network-scripts``."

    INTERFACE_DIR = "/etc/sysconfig/network-scripts"
    confine :exists => INTERFACE_DIR
    defaultfor :operatingsystem => [:fedora, :centos, :redhat]

    # Create the setter/gettor methods to match the model.
    mk_resource_methods

    @templates = {}

    # Register a template.
    def self.register_template(name, string)
        @templates[name] = ERB.new(string)
    end

    # Retrieve a template by name.
    def self.template(name)
        @templates[name]
    end

    register_template :alias, <<-ALIAS
DEVICE=<%= self.device %>
ONBOOT=<%= self.on_boot %>
BOOTPROTO=none
IPADDR=<%= self.name %>
NETMASK=<%= self.netmask %>
BROADCAST=
ALIAS


    register_template :normal, <<-LOOPBACKDUMMY
DEVICE=<%= self.device %>
ONBOOT=<%= self.on_boot %>
BOOTPROTO=static
IPADDR=<%= self.name %>
NETMASK=<%= self.netmask %>
BROADCAST=
LOOPBACKDUMMY

    # maximum number of dummy interfaces
    @max_dummies = 10

    # maximum number of aliases per interface
    @max_aliases_per_iface = 10

    @@dummies = []
    @@aliases = Hash.new { |hash, key| hash[key] = [] }

    # calculate which dummy interfaces are currently already in
    # use prior to needing to call self.next_dummy later on.
    def self.instances
        # parse all of the config files at once
        Dir.glob("%s/ifcfg-*" % INTERFACE_DIR).collect do |file|
            record = parse(file)

            # store the existing dummy interfaces
            @@dummies << record[:ifnum] if (record[:interface_type] == :dummy and ! @@dummies.include?(record[:ifnum]))

            @@aliases[record[:interface]] << record[:ifnum] if record[:interface_type] == :alias

            new(record)
        end
    end

    # return the next avaliable dummy interface number, in the case where
    # ifnum is not manually specified
    def self.next_dummy
        @max_dummies.times do |i|
            unless @@dummies.include?(i.to_s)
                @@dummies << i.to_s
                return i.to_s
            end
        end
    end

    # return the next available alias on a given interface, in the case
    # where ifnum if not manually specified
    def self.next_alias(interface)
        @max_aliases_per_iface.times do |i|
            unless @@aliases[interface].include?(i.to_s)
                @@aliases[interface] << i.to_s
                return i.to_s
            end
        end
    end

    # base the ifnum, for dummy / loopback interface in linux
    # on the last octect of the IP address

    # Parse the existing file.
    def self.parse(file)
        instance = new()
        return instance unless FileTest.exist?(file)

        File.readlines(file).each do |line|
            if line =~ /^(\w+)=(.+)$/
                instance.send($1.downcase + "=", $2)
            end
        end

        return instance
    end

    # Prefetch our interface list, yo.
    def self.prefetch(resources)
        instances.each do |prov|
            if resource = resources[prov.name]
                resource.provider = prov
            end
        end
    end

    def create
        self.class.resource_type.validproperties.each do |property|
            if value = @resource.should(property)
                @property_hash[property] = value
            end
        end
        @property_hash[:name] = @resource.name

        return (@resource.class.name.to_s + "_created").intern
    end

    def destroy
        File.unlink(file_path)
    end

    def exists?
        FileTest.exist?(file_path)
    end

    # generate the content for the interface file, so this is dependent
    # on whether we are adding an alias to a real interface, or a loopback
    # address (also dummy) on linux. For linux it's quite involved, and we
    # will use an ERB template
    def generate
        itype = self.interface_type == :alias ? :alias : :normal
        self.class.template(itype).result(binding)
    end

    # Where should the file be written out?
    # This defaults to INTERFACE_DIR/ifcfg-<namevar>, but can have a
    # more symbolic name by setting interface_desc in the type. 
    def file_path
        if resource and val = resource[:interface_desc]
            desc = val
        else
            desc = self.name
        end

        self.fail("Could not get name for interface") unless desc

        if self.interface_type == :alias
            return File.join(INTERFACE_DIR, "ifcfg-" + self.interface + ":" + desc)
        else
            return File.join(INTERFACE_DIR, "ifcfg-" + desc)
        end
    end

    # Use the device value to figure out all kinds of nifty things.
    def device=(value)
        case value
        when /:/:
            @property_hash[:interface], @property_hash[:ifnum] = value.split(":")
            @property_hash[:interface_type] = :alias
        when /^dummy/:
            @property_hash[:interface_type] = :loopback
            @property_hash[:interface] = "dummy"

            # take the number of the dummy interface, as this is used
            # when working out whether to call next_dummy when dynamically
            # creating these
            @property_hash[:ifnum] = value.sub("dummy",'')

            @@dummies << @property_hash[:ifnum].to_s unless @@dummies.include?(@property_hash[:ifnum].to_s)
        else
            @property_hash[:interface_type] = :normal
            @property_hash[:interface] = value
        end
    end

    # create the device name, so this based on the IP, and interface + type
    def device
        case @resource.should(:interface_type)
        when :loopback
            @property_hash[:ifnum] ||= self.class.next_dummy
            return "dummy" + @property_hash[:ifnum]
        when :alias
            @property_hash[:ifnum] ||= self.class.next_alias(@resource[:interface])
            return @resource[:interface] + ":" + @property_hash[:ifnum]
        end
    end

    # Set the name to our ip address.
    def ipaddr=(value)
        @property_hash[:name] = value
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

    # Mark whether the interface should be started on boot.
    def on_boot=(value)
        # translate whether we come up on boot to true/false
        case value.downcase
        when "yes":
            @property_hash[:onboot] = :true
        else
            @property_hash[:onboot] = :false
        end
    end

    # Write the new file out.
    def flush
        # Don't flush to disk if we're removing the config.
        return if self.ensure == :absent

        @property_hash.each do |name, val|
            if val == :absent
                raise ArgumentError, "Propety %s must be provided" % val
            end
        end

        File.open(file_path, "w") do |f|
            f.puts generate()
        end
    end

    def prefetch
        @property_hash = self.class.parse(file_path)
    end
end

