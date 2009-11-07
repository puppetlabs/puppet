require 'syslog'
require 'puppet/util/tagging'
require 'puppet/util/classgen'

# Pass feedback to the user.  Log levels are modeled after syslog's, and it is
# expected that that will be the most common log destination.  Supports
# multiple destinations, one of which is a remote server.
class Puppet::Util::Log
    include Puppet::Util
    extend Puppet::Util::ClassGen
    include Puppet::Util::Tagging

    @levels = [:debug,:info,:notice,:warning,:err,:alert,:emerg,:crit]
    @loglevel = 2

    @desttypes = {}

    # Create a new destination type.
    def self.newdesttype(name, options = {}, &block)
        dest = genclass(name, :parent => Puppet::Util::Log::Destination, :prefix => "Dest",
            :block => block,
            :hash => @desttypes,
            :attributes => options
        )
        dest.match(dest.name)

        return dest
    end

    require 'puppet/util/log/destination'
    require 'puppet/util/log/destinations'

    @destinations = {}

    class << self
        include Puppet::Util
        include Puppet::Util::ClassGen

        attr_reader :desttypes
    end

    # Reset all logs to basics.  Basically just closes all files and undefs
    # all of the other objects.
    def Log.close(dest = nil)
        if dest
            if @destinations.include?(dest)
                if @destinations.respond_to?(:close)
                    @destinations[dest].close
                end
                @destinations.delete(dest)
            end
        else
            @destinations.each { |name, dest|
                if dest.respond_to?(:flush)
                    dest.flush
                end
                if dest.respond_to?(:close)
                    dest.close
                end
            }
            @destinations = {}
        end
    end

    def self.close_all
        # And close all logs except the console.
        destinations.each do |dest|
            close(dest)
        end
    end

    # Flush any log destinations that support such operations.
    def Log.flush
        @destinations.each { |type, dest|
            if dest.respond_to?(:flush)
                dest.flush
            end
        }
    end

    # Create a new log message.  The primary role of this method is to
    # avoid creating log messages below the loglevel.
    def Log.create(hash)
        unless hash.include?(:level)
            raise Puppet::DevError, "Logs require a level"
        end
        unless @levels.index(hash[:level])
            raise Puppet::DevError, "Invalid log level %s" % hash[:level]
        end
        if @levels.index(hash[:level]) >= @loglevel
            return Puppet::Util::Log.new(hash)
        else
            return nil
        end
    end

    def Log.destinations
        return @destinations.keys
    end

    # Yield each valid level in turn
    def Log.eachlevel
        @levels.each { |level| yield level }
    end

    # Return the current log level.
    def Log.level
        return @levels[@loglevel]
    end

    # Set the current log level.
    def Log.level=(level)
        unless level.is_a?(Symbol)
            level = level.intern
        end

        unless @levels.include?(level)
            raise Puppet::DevError, "Invalid loglevel %s" % level
        end

        @loglevel = @levels.index(level)
    end

    def Log.levels
        @levels.dup
    end

    # Create a new log destination.
    def Log.newdestination(dest)
        # Each destination can only occur once.
        if @destinations.find { |name, obj| obj.name == dest }
            return
        end

        name, type = @desttypes.find do |name, klass|
            klass.match?(dest)
        end

        unless type
            raise Puppet::DevError, "Unknown destination type %s" % dest
        end

        begin
            if type.instance_method(:initialize).arity == 1
                @destinations[dest] = type.new(dest)
            else
                @destinations[dest] = type.new()
            end
        rescue => detail
            if Puppet[:debug]
                puts detail.backtrace
            end

            # If this was our only destination, then add the console back in.
            if @destinations.empty? and (dest != :console and dest != "console")
                newdestination(:console)
            end
        end
    end

    # Route the actual message. FIXME There are lots of things this method
    # should do, like caching, storing messages when there are not yet
    # destinations, a bit more.  It's worth noting that there's a potential
    # for a loop here, if the machine somehow gets the destination set as
    # itself.
    def Log.newmessage(msg)
        if @levels.index(msg.level) < @loglevel
            return
        end

        @destinations.each do |name, dest|
            threadlock(dest) do
                dest.handle(msg)
            end
        end
    end

    def Log.sendlevel?(level)
        @levels.index(level) >= @loglevel
    end

    # Reopen all of our logs.
    def Log.reopen
        Puppet.notice "Reopening log files"
        types = @destinations.keys
        @destinations.each { |type, dest|
            if dest.respond_to?(:close)
                dest.close
            end
        }
        @destinations.clear
        # We need to make sure we always end up with some kind of destination
        begin
            types.each { |type|
                Log.newdestination(type)
            }
        rescue => detail
            if @destinations.empty?
                Log.newdestination(:syslog)
                Puppet.err detail.to_s
            end
        end
    end

    # Is the passed level a valid log level?
    def self.validlevel?(level)
        @levels.include?(level)
    end

    attr_accessor :time, :remote, :file, :line, :version, :source
    attr_reader :level, :message

    def initialize(args)
        self.level = args[:level]
        self.message = args[:message]
        self.source = args[:source] || "Puppet"

        @time = Time.now

        if tags = args[:tags]
            tags.each { |t| self.tag(t) }
        end

        [:file, :line, :version].each do |attr|
            next unless value = args[attr]
            send(attr.to_s + "=", value)
        end

        Log.newmessage(self)
    end
    
    def message=(msg)
        raise ArgumentError, "Puppet::Util::Log requires a message" unless msg
        @message = msg.to_s
    end

    def level=(level)
        raise ArgumentError, "Puppet::Util::Log requires a log level" unless level
        @level = level.to_sym
        raise ArgumentError, "Invalid log level %s" % @level unless self.class.validlevel?(@level)

        # Tag myself with my log level
        tag(level)
    end

    # If they pass a source in to us, we make sure it is a string, and
    # we retrieve any tags we can.
    def source=(source)
        if source.respond_to?(:source_descriptors)
            descriptors = source.source_descriptors
            @source = descriptors[:path]

            descriptors[:tags].each { |t| tag(t) }

            [:file, :line, :version].each do |param|
                next unless descriptors[param]
                send(param.to_s + "=", descriptors[param])
            end
        else
            @source = source.to_s
        end
    end

    def to_report
        "#{time} #{source} (#{level}): #{to_s}"
    end

    def to_s
        message
    end
end

# This is for backward compatibility from when we changed the constant to Puppet::Util::Log
# because the reports include the constant name.  Apparently the alias was created in
# March 2007, should could probably be removed soon.
Puppet::Log = Puppet::Util::Log
