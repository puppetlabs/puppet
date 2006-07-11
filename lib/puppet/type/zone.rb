Puppet::Type.newtype(:zone) do
    @doc = "Solaris zones."

    # These states modify the zone configuration, and they need to provide
    # the text separately from syncing it, so all config statements can be rolled
    # into a single creation statement.
    class ZoneConfigState < Puppet::State
        # Perform the config operation.
        def sync
            @parent.cfg self.configtext
        end
    end

    # Those states that can have multiple instances.
    class ZoneMultiConfigState < ZoneConfigState
        def configtext
            list = @should

            unless @is.is_a? Symbol
                if @is.is_a? Array
                    list += @is
                else
                    if @is
                        list << @is
                    end
                end
            end

            # Some hackery so we can test whether @is is an array or a symbol
            if @is.is_a? Array
                tmpis = @is
            else
                if @is
                    tmpis = [@is]
                else
                    tmpis = []
                end
            end

            rms = []
            adds = []
            # Collect the modifications to make
            list.sort.uniq.collect do |obj|
                # Skip objectories that are configured and should be
                next if tmpis.include?(obj) and @should.include?(obj)

                if tmpis.include?(obj)
                    rms << obj
                else
                    adds << obj
                end
            end

            # And then perform all of the removals before any of the adds.
            (rms.collect { |o| rm(o) } + adds.collect { |o| add(o) }).join("\n")
        end

        # We want all specified directories to be included.
        def insync?
            if @is.is_a? Array and @should.is_a? Array
                @is.sort == @should.sort
            else
                @is == @should
            end
        end
    end

    ensurable do
        desc "The running state of the zone.  The valid states directly reflect
            the states that ``zoneadm`` provides.  The states are linear,
            in that a zone must be ``configured`` then ``installed``, and
            only then can be ``running``.  Note also that ``halt`` is currently
            used to stop zones."

        @states = {}

        def self.newvalue(name, hash)
            if @parametervalues.is_a? Hash
                @parametervalues = []
            end

            @parametervalues << name

            @states[name] = hash
            hash[:name] = name
        end

        newvalue :absent, :down => :destroy
        newvalue :configured, :up => :configure, :down => :uninstall
        newvalue :installed, :up => :install, :down => :stop
        newvalue :running, :up => :start

        defaultto :running

        def self.valueindex(value)
            @parametervalues.index(value)
        end

        # Return all of the states between two listed values, exclusive
        # of the first item.
        def self.valueslice(first, second)
            findex = sindex = nil
            unless findex = @parametervalues.index(first)
                raise ArgumentError, "'%s' is not a valid zone state" % first
            end
            unless sindex = @parametervalues.index(second)
                raise ArgumentError, "'%s' is not a valid zone state" % first
            end
            list = nil

            # Apparently ranges are unidirectional, so we have to reverse
            # the range op twice.
            if findex > sindex
                list = @parametervalues[sindex..findex].collect do |name|
                    @states[name]
                end.reverse
            else
                list = @parametervalues[findex..sindex].collect do |name|
                    @states[name]
                end
            end

            # The first result is the current state, so don't return it.
            list[1..-1]
        end

        def is=(value)
            value = value.intern if value.is_a? String
            @is = value
        end

        def sync
            method = nil
            if up?
                dir = :up
            else
                dir = :down
            end

            # We need to get the state we're currently in and just call
            # everything between it and us.
            states = self.class.valueslice(self.is, self.should)

            states.each do |st|
                if method = st[dir]
                    warned = false
                    while @parent.processing?
                        unless warned
                            info "Waiting for zone to finish processing"
                            warned = true
                        end
                        sleep 1
                    end
                    @parent.send(method)
                else
                    raise Puppet::DevError, "Cannot move %s from %s" %
                        [dir, st[:name]]
                end
            end

            return ("zone_" + self.should.to_s).intern
        end

        # Are we moving up the state tree?
        def up?
            self.class.valueindex(self.is) < self.class.valueindex(self.should)
        end
    end

    newparam(:name) do
        desc "The name of the zone."

        isnamevar
    end

    newparam(:id) do
        desc "The numerical ID of the zone.  This number is autogenerated
            and cannot be changed."
    end

    newstate(:ip, ZoneMultiConfigState) do
        require 'ipaddr'

        desc "The IP address of the zone.  IP addresses must be specified
            with the interface, separated by a colon, e.g.: bge0:192.168.0.1.
            For multiple interfaces, specify them in an array."

        validate do |value|
            unless value =~ /:/
                raise ArgumentError,
                    "IP addresses must specify the interface and the address, separated by a colon."
            end

            interface, address = value.split(':')
            
            begin
                IPAddr.new(address)
            rescue ArgumentError
                raise ArgumentError, "'%s' is an invalid IP address" % address
            end
        end

        # Add a directory to our list of inherited directories.
        def add(str)
            interface, ip = ipsplit(str)
            "add net
set address=#{ip}
set physical=#{interface}
end
"
        end

        # Convert a string into the component interface and address 
        def ipsplit(str)
            interface, address = str.split(':')
            return interface, address
        end

        def rm(str)
            interface, ip = ipsplit(str)
            # Reality seems to disagree with the documentation here; the docs
            # specify that braces are required, but they're apparently only
            # required if you're specifying multiple values.
            "remove net address=#{ip}"
        end
    end

    newstate(:autoboot, ZoneConfigState) do
        desc "Whether the zone should automatically boot."

        defaultto true

        newvalue(:true) {}
        newvalue(:false) {}

        def configtext
            "set autoboot=#{self.should}"
        end
    end

    newstate(:pool, ZoneConfigState) do
        desc "The resource pool for this zone." 

        def configtext
            "set pool=#{self.should}"
        end
    end

    newstate(:inherit, ZoneMultiConfigState) do
        desc "The list of directories that the zone inherits from the global
            zone.  All directories must be fully qualified."

        validate do |value|
            unless value =~ /^\//
                raise ArgumentError, "The zone base must be fully qualified"
            end
        end

        # Add a directory to our list of inherited directories.
        def add(dir)
            "add inherit-pkg-dir\nset dir=#{dir}\nend"
        end

        def rm(dir)
            # Reality seems to disagree with the documentation here; the docs
            # specify that braces are required, but they're apparently only
            # required if you're specifying multiple values.
            "remove inherit-pkg-dir dir=#{dir}"
        end

        def should
            @should
        end
    end

    # Specify the sysidcfg file.  This is pretty hackish, because it's
    # only used to boot the zone the very first time.
    newparam(:sysidcfg) do
        desc %{The text to go into the sysidcfg file when the zone is first
            booted.  The best way is to use a template:
                
                # $templatedir/sysidcfg
                system_locale=en_US
                timezone=GMT
                terminal=xterms
                security_policy=NONE
                root_password=<%= password %>
                timeserver=localhost
                name_service=DNS {domain_name=<%= domain %>
                        name_server=<%= nameserver %>}
                network_interface=primary {hostname=<%= name %>
                        ip_address=<%= ip %>
                        netmask=<%= netmask %>
                        protocol_ipv6=no
                        default_route=<%= defaultroute %>}
                nfs4_domain=dynamic

            And then call that:

                zone { myzone:
                    ip => "bge0:192.168.0.23",
                    sysidcfg => template(sysidcfg),
                    path => "/opt/zones/myzone"
                }

            The sysidcfg only matters on the first booting of the zone,
            so Puppet only checks for it at that time.
        }
    end

    newparam(:path) do
        desc "The root of the zone's filesystem.  Must be a fully qualified
            file name.  If you include '%s' in the path, then it will be
            replaced with the zone's name.  At this point, you cannot use
            Puppet to move a zone."

        validate do |value|
            unless value =~ /^\//
                raise ArgumentError, "The zone base must be fully qualified"
            end
        end

        munge do |value|
            if value =~ /%s/
                value % @parent[:name]
            else
                value
            end
        end
    end

    # If Puppet is also managing the base dir or its parent dir, list them
    # both as prerequisites.
    autorequire(:file) do
        if @parameters.include? :path
            [@parameters[:path].value, File.dirname(@parameters[:path].value)]
        else
            nil
        end
    end

    # Convert the output of a list into a hash
    def self.line2hash(line)
        fields = [:id, :name, :ensure, :path]

        hash = {}
        line.split(":").each_with_index { |value, index|
            hash[fields[index]] = value
        }

        # Configured but not installed zones do not have IDs
        if hash[:id] == "-"
            hash.delete(:id)
        end

        return hash
    end

    def self.list
        %x{/usr/sbin/zoneadm list -cp}.split("\n").collect do |line|
            hash = line2hash(line)

            obj = nil
            unless obj = @objects[hash[:name]]
                obj = create(:name => hash[:name])
            end

            obj.setstatus(hash)

            obj
        end
    end

    # Execute a configuration string.  Can't be private because it's called
    # by the states.
    def cfg(str)
        debug "Executing '%s' in zone %s" % [str, self[:name]]
        IO.popen("/usr/sbin/zonecfg -z %s -f - 2>&1" % self[:name], "w") do |pipe|
            pipe.puts str
        end

        unless $? == 0
            raise ArgumentError, "Failed to apply configuration"
        end
    end

    # Perform all of our configuration steps.
    def configure
        # If the thing is entirely absent, then we need to create the config.
        str = %{create -b
set zonepath=%s
} % self[:path]

        # Then perform all of our configuration steps.
        @states.each do |name, state|
            if state.is_a? ZoneConfigState and ! state.insync?
                str += state.configtext + "\n"
            end
        end

        str += "commit\n"
        cfg(str)
    end

    def destroy
        begin
            execute("/usr/sbin/zonecfg -z #{self[:name]} delete -F")
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not destroy zone: %s" % detail
        end
    end

    def install
        begin
            execute("/usr/sbin/zoneadm -z #{self[:name]} install")
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not install zone: %s" % detail
        end
    end

    # We need a way to test whether a zone is in process.  Our 'ensure'
    # state models the static states, but we need to handle the temporary ones.
    def processing?
        if hash = statushash()
            case hash[:ensure]
            when "incomplete", "ready", "shutting_down"
                true
            else
                false
            end
        else
            false
        end
    end

    def retrieve
        if hash = statushash()
            setstatus(hash)

            # Now retrieve the configuration itself and set appropriately.
            getconfig()
        else
            @states.each do |name, state|
                state.is = :absent
            end
        end
    end

    # Take the results of a listing and set everything appropriately.
    def setstatus(hash)
        hash.each do |param, value|
            next if param == :name
            case self.class.attrtype(param)
            when :state:
                self.is = [param, value]
            else
                self[param] = value
            end
        end

        # For any configured items that are not found, mark absent.
        @states.each do |name, st|
            next unless st.is_a? ZoneConfigState

            unless hash.has_key? st.name
                st.is = :absent
            end
        end
    end

    def start
        # Check the sysidcfg stuff
        if cfg = self[:sysidcfg]
            path = File.join(self[:path], "root", "etc", "sysidcfg")

            unless File.exists?(path)
                begin
                    File.open(path, "w", 0600) do |f|
                        f.puts cfg
                    end
                rescue => detail
                    if Puppet[:debug]
                        puts detail.stacktrace
                    end
                    raise Puppet::Error, "Could not create sysidcfg: %s" % detail
                end
            end
        end

        begin
            execute("/usr/sbin/zoneadm -z #{self[:name]} boot")
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not start zone: %s" % detail
        end
    end

    def stop
        begin
            execute("/usr/sbin/zoneadm -z #{self[:name]} halt")
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not halt zone: %s" % detail
        end
    end

    def unconfigure
        begin
            execute("/usr/sbin/zonecfg -z #{self[:name]} delete -F")
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not unconfigure zone: %s" % detail
        end
    end

    def uninstall
        begin
            execute("/usr/sbin/zoneadm -z #{self[:name]} uninstall -F")
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not halt zone: %s" % detail
        end
    end

    private

    # Turn the results of getconfig into status information.
    def config2status(config)
        config.each do |name, value|
            case name
            when :autoboot:
                self.is = [:autoboot, value.intern]
            when :zonepath:
                # Nothing; this is set in the zoneadm list command
            when :pool:
                self.is = [:pool, value]
            when "inherit-pkg-dir":
                dirs = value.collect do |hash|
                    hash[:dir]
                end

                self.is = [:inherit, dirs]
            when "net":
                vals = value.collect do |hash|
                    "%s:%s" % [hash[:physical], hash[:address]]
                end
                self.is = [:ip, vals]
            end
        end
    end

    # Collect the configuration of the zone.
    def getconfig
        output = execute("/usr/sbin/zonecfg -z %s info" % self[:name])

        name = nil
        current = nil
        hash = {}
        output.split("\n").each do |line|
            case line
            when /^(\S+):\s*$/:
                name = $1
                current = nil # reset it
            when /^(\S+):\s*(.+)$/:
                hash[$1.intern] = $2
                #self.is = [$1.intern, $2]
            when /^\s+(\S+):\s*(.+)$/:
                if name
                    unless hash.include? name
                        hash[name] = []
                    end

                    unless current
                        current = {}
                        hash[name] << current
                    end
                    current[$1.intern] = $2
                else
                    err "Ignoring '%s'" % line
                end
            else
                debug "Ignoring zone output '%s'" % line
            end
        end
        config2status(hash)
    end

    def statushash
        begin
            output = execute("/usr/sbin/zoneadm -z #{self[:name]} list -p 2>/dev/null")
        rescue Puppet::ExecutionFailure => detail
            return nil
        end

        return self.class.line2hash(output.chomp)
    end
end

# $Id$
