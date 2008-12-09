# Manage NetInfo POSIX objects.
#
# This provider has been deprecated. You should be using the directoryservice
# nameservice provider instead.

require 'puppet'
require 'puppet/provider/nameservice'

class Puppet::Provider::NameService
class NetInfo < Puppet::Provider::NameService
    class << self
        attr_writer :netinfodir
    end

    # We have to initialize manually because we're not using
    # classgen() here.
    initvars()

    commands :lookupd => "/usr/sbin/lookupd"

    # Attempt to flush the database, but this doesn't seem to work at all.
    def self.flush
        begin
            lookupd "-flushcache"
        rescue Puppet::ExecutionFailure
            # Don't throw an error; it's just a failed cache flush
            Puppet.err "Could not flush lookupd cache: %s" % output
        end
    end

    # Similar to posixmethod, what key do we use to get data?  Defaults
    # to being the object name.
    def self.netinfodir
        if defined? @netinfodir
            return @netinfodir
        else
            return @resource_type.name.to_s + "s"
        end
    end

    def self.finish
        case self.name
        when :uid:
            noautogen
        when :gid:
            noautogen
        end
    end
    
    def self.instances
        warnonce "The NetInfo provider is deprecated; use directoryservice instead"
        report(@resource_type.validproperties).collect do |hash|
            self.new(hash)
        end
    end
    
    # Convert a NetInfo line into a hash of data.
    def self.line2hash(line, params)
        values = line.split(/\t/)

        hash = {}
        params.zip(values).each do |param, value|
            next if value == '#NoValue#'
            hash[param] = if value =~ /^[-0-9]+$/
                Integer(value)
            else
                value
            end
        end
        hash
    end
    
    # What field the value is stored under.
    def self.netinfokey(name)
        name = symbolize(name)
        self.option(name, :key) || name
    end
    
    # Retrieve the data, yo.
    # FIXME This should retrieve as much information as possible,
    # rather than retrieving it one at a time.
    def self.report(*params)
        dir = self.netinfodir()
        cmd = [command(:nireport), "/", "/%s" % dir]
        
        params.flatten!

        # We require the name in order to know if we match.  There's no
        # way to just report on our individual object, we have to get the
        # whole list.
        params.unshift :name unless params.include? :name

        params.each do |param|
            if key = netinfokey(param)
                cmd << key.to_s
            else
                raise Puppet::DevError,
                    "Could not find netinfokey for property %s" %
                    self.class.name
            end
        end

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            Puppet.err "Failed to call nireport: %s" % detail
            return nil
        end

        return output.split("\n").collect { |line|
            line2hash(line, params)
        }
    end
    
    # How to add an object.
    def addcmd
        creatorcmd("-create")
    end

    def creatorcmd(arg)
        cmd = [command(:niutil)]
        cmd << arg

        cmd << "/" << "/%s/%s" % [self.class.netinfodir(), @resource[:name]]
        return cmd
    end

    def deletecmd
        creatorcmd("-destroy")
    end
    
    def destroy
        delete()
    end

    def ensure=(arg)
        warnonce "The NetInfo provider is deprecated; use directoryservice instead"
        super

        # Because our stupid type can't create the whole thing at once,
        # we have to do this hackishness.  Yay.
        if arg == :present
            @resource.class.validproperties.each do |name|
                next if name == :ensure

                # LAK: We use property.sync here rather than directly calling
                # the settor method because the properties might do some kind
                # of conversion.  In particular, the user gid property might
                # have a string and need to convert it to a number
                if @resource.should(name)
                    @resource.property(name).sync
                elsif value = autogen(name)
                    self.send(name.to_s + "=", value)
                else
                    next
                end
            end
        end
    end

    # Retrieve a specific value by name.
    def get(param)
        hash = getinfo(false)
        if hash
            return hash[param]
        else
            return :absent
        end
    end

    # Retrieve everything about this object at once, instead of separately.
    def getinfo(refresh = false)
        if refresh or (! defined? @infohash or ! @infohash)
            properties = [:name] + self.class.resource_type.validproperties
            properties.delete(:ensure) if properties.include? :ensure
            @infohash = single_report(*properties)
        end

        return @infohash
    end

    def modifycmd(param, value)
        cmd = [command(:niutil)]
        # if value.is_a?(Array)
        #     warning "Netinfo providers cannot currently handle multiple values"
        # end

        cmd << "-createprop" << "/" << "/%s/%s" % [self.class.netinfodir, @resource[:name]]

        value = [value] unless value.is_a?(Array)
        if key = netinfokey(param)
            cmd << key
            cmd += value
        else
            raise Puppet::DevError,
                "Could not find netinfokey for property %s" %
                self.class.name
        end
        cmd
    end

    # Determine the flag to pass to our command.
    def netinfokey(name)
        self.class.netinfokey(name)
    end
    
    # Get a report for a single resource, not the whole table
    def single_report(*properties)
        warnonce "The NetInfo provider is deprecated; use directoryservice instead"
        self.class.report(*properties).find do |hash| hash[:name] == self.name end
    end

    def setuserlist(group, list)
        cmd = [command(:niutil), "-createprop", "/", "/groups/%s" % group, "users", list.join(",")]
        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Failed to set user list on %s: %s" %
                [group, detail]
        end
    end
end
end

