Puppet::Type.type(:zone).provide(:solaris) do
    desc "Provider for Solaris Zones."

    commands :adm => "/usr/sbin/zoneadm", :cfg => "/usr/sbin/zonecfg"
    defaultfor :operatingsystem => :solaris

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
        adm(:list, "-cp").split("\n").collect do |line|
            hash = line2hash(line)

            obj = nil
            unless obj = @resource[hash[:name]]
                obj = @resource.create(:name => hash[:name])
            end

            obj.setstatus(hash)

            obj
        end
    end

    # Perform all of our configuration steps.
    def configure
        # If the thing is entirely absent, then we need to create the config.
        str = %{create -b
set zonepath=%s
} % @resource[:path]

        # Then perform all of our configuration steps.  It's annoying
        # that we need this much internal info on the resource.
        @resource.send(:properties).each do |property|
            if property.is_a? ZoneConfigProperty and ! property.insync?
                str += property.configtext + "\n"
            end
        end

        str += "commit\n"
        setconfig(str)
    end

    def destroy
        zonecfg :delete, "-F"
    end

    def install
        zoneadm :install
    end

    # We need a way to test whether a zone is in process.  Our 'ensure'
    # property models the static states, but we need to handle the temporary ones.
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

    # Collect the configuration of the zone.
    def getconfig
        output = zonecfg :info

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
        return hash
    end

    def retrieve
        if hash = statushash()
            setstatus(hash)

            # Now retrieve the configuration itself and set appropriately.
            getconfig()
        end
    end

    # Execute a configuration string.  Can't be private because it's called
    # by the properties.
    def setconfig(str)
        command = "#{command(:cfg)} -z %s -f -" % @resource[:name]
        debug "Executing '%s' in zone %s with '%s'" % [command, @resource[:name], str]
        IO.popen(command, "w") do |pipe|
            pipe.puts str
        end

        unless $? == 0
            raise ArgumentError, "Failed to apply configuration"
        end
    end

    def start
        # Check the sysidcfg stuff
        if cfg = @resource[:sysidcfg]
            path = File.join(@resource[:path], "root", "etc", "sysidcfg")

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

        zoneadm :boot
    end

    # Return a hash of the current status of this zone.
    def statushash
        begin
            output = adm "-z", @resource[:name], :list, "-p"
        rescue Puppet::ExecutionFailure
            return nil
        end

        return self.class.line2hash(output.chomp)
    end

    def stop
        zoneadm :halt
    end

    def unconfigure
        zonecfg :delete, "-F"
    end

    def uninstall
        zoneadm :uninstall, "-F"
    end

    private

    def zoneadm(*cmd)
        begin
            adm("-z", @resource[:name], *cmd)
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not %s zone: %s" % [cmd[0], detail]
        end
    end

    def zonecfg(*cmd)
        begin
            cfg("-z", @resource[:name], *cmd)
        rescue Puppet::ExecutionFailure => detail
            self.fail "Could not %s zone: %s" % [cmd[0], detail]
        end
    end
end

# $Id$
