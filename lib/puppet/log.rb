require 'syslog'

module Puppet
    # Pass feedback to the user.  Log levels are modeled after syslog's, and it is
    # expected that that will be the most common log destination.  Supports
    # multiple destinations, one of which is a remote server.
	class Log
        PINK="[0;31m"
        GREEN="[0;32m"
        YELLOW="[0;33m"
        SLATE="[0;34m"
        ORANGE="[0;35m"
        BLUE="[0;36m"
        RESET="[0m"

        @levels = [:debug,:info,:notice,:warning,:err,:alert,:emerg,:crit]
        @loglevel = 2

        @desttypes = {}

        # A type of log destination.
        class Destination
            class << self
                attr_accessor :name
            end

            # Mark the things we're supposed to match.
            def self.match(obj)
                @matches ||= []
                @matches << obj
            end

            # See whether we match a given thing.
            def self.match?(obj)
                if obj.is_a? String and obj =~ /^\w+$/
                    obj = obj.downcase.intern
                end
                @matches.each do |thing|
                    return true if thing === obj
                end
                return false
            end

            def name
                if defined? @name
                    return @name
                else
                    return self.class.name
                end
            end

            # Set how to handle a message.
            def self.sethandler(&block)
                define_method(:handle, &block)
            end

            # Mark how to initialize our object.
            def self.setinit(&block)
                define_method(:initialize, &block)
            end
        end

        # Create a new destination type.
        def self.newdesttype(name, options = {}, &block)
            dest = Class.new(Destination)
            name = name.to_s.downcase.intern
            dest.name = name
            dest.match(dest.name)

            const_set("Dest" + name.to_s.capitalize, dest)

            @desttypes[dest.name] = dest

            options.each do |option, value|
                begin
                    dest.send(option.to_s + "=", value)
                rescue NoMethodError
                    raise "%s is an invalid option for log destinations" % option
                end
            end

            dest.class_eval(&block)

            return dest
        end

        @destinations = {}

        class << self
            include Puppet::Util
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
                return Puppet::Log.new(hash)
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

        newdesttype :syslog do
            def close
                Syslog.close
            end

            def initialize
                if Syslog.opened?
                    Syslog.close
                end
                name = Puppet.name
                name = "puppet-#{name}" unless name =~ /puppet/

                options = Syslog::LOG_PID | Syslog::LOG_NDELAY

                # XXX This should really be configurable.
                facility = Syslog::LOG_DAEMON

                @syslog = Syslog.open(name, options, facility)
            end

            def handle(msg)
                # XXX Syslog currently has a bug that makes it so you
                # cannot log a message with a '%' in it.  So, we get rid
                # of them.
                if msg.source == "Puppet"
                    @syslog.send(msg.level, msg.to_s.gsub("%", '%%'))
                else
                    @syslog.send(msg.level, "(%s) %s" %
                        [msg.source.to_s.gsub("%", ""),
                            msg.to_s.gsub("%", '%%')
                        ]
                    )
                end
            end
        end

        newdesttype :file do
            match /^\//

            def close
                if defined? @file
                    @file.close
                    @file = nil
                end
            end

            def flush
                if defined? @file
                    @file.flush
                end
            end

            def initialize(path)
                @name = path
                # first make sure the directory exists
                # We can't just use 'Config.use' here, because they've
                # specified a "special" destination.
                unless FileTest.exist?(File.dirname(path))
                    Puppet.recmkdir(File.dirname(path))
                    Puppet.info "Creating log directory %s" % File.dirname(path)
                end

                # create the log file, if it doesn't already exist
                file = File.open(path, File::WRONLY|File::CREAT|File::APPEND)

                @file = file
            end

            def handle(msg)
                @file.puts("%s %s (%s): %s" %
                    [msg.time, msg.source, msg.level, msg.to_s])
            end
        end

        newdesttype :console do
            @@colors = {
                :debug => SLATE,
                :info => GREEN,
                :notice => PINK,
                :warning => ORANGE,
                :err => YELLOW,
                :alert => BLUE,
                :emerg => RESET,
                :crit => RESET
            }

            def initialize
                # Flush output immediately.
                $stdout.sync = true
            end

            def handle(msg)
                color = ""
                reset = ""
                if Puppet[:color]
                    color = @@colors[msg.level]
                    reset = RESET
                end
                if msg.source == "Puppet"
                    puts color + "%s: %s" % [
                        msg.level, msg.to_s
                    ] + reset
                else
                    puts color + "%s: %s: %s" % [
                        msg.level, msg.source, msg.to_s
                    ] + reset
                end
            end
        end

        newdesttype :host do
            def initialize(host)
                Puppet.info "Treating %s as a hostname" % host
                args = {}
                if host =~ /:(\d+)/
                    args[:Port] = $1
                    args[:Server] = host.sub(/:\d+/, '')
                else
                    args[:Server] = host
                end

                @name = host

                @driver = Puppet::Client::LogClient.new(args)
            end

            def handle(msg)
                unless msg.is_a?(String) or msg.remote
                    unless defined? @hostname
                        @hostname = Facter["hostname"].value
                    end
                    unless defined? @domain
                        @domain = Facter["domain"].value
                        if @domain
                            @hostname += "." + @domain
                        end
                    end
                    if msg.source =~ /^\//
                        msg.source = @hostname + ":" + msg.source
                    elsif msg.source == "Puppet"
                        msg.source = @hostname + " " + msg.source
                    else
                        msg.source = @hostname + " " + msg.source
                    end
                    begin
                        #puts "would have sent %s" % msg
                        #puts "would have sent %s" %
                        #    CGI.escape(YAML.dump(msg))
                        begin
                            tmp = CGI.escape(YAML.dump(msg))
                        rescue => detail
                            puts "Could not dump: %s" % detail.to_s
                            return
                        end
                        # Add the hostname to the source
                        @driver.addlog(tmp)
                        sleep(0.5)
                    rescue => detail
                        if Puppet[:debug]
                            puts detail.backtrace
                        end
                        Puppet.err detail
                        Puppet::Log.close(self)
                    end
                end
            end
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

		attr_accessor :level, :message, :time, :tags, :remote
        attr_reader :source

		def initialize(args)
			unless args.include?(:level) && args.include?(:message)
				raise Puppet::DevError, "Puppet::Log called incorrectly"
			end

			if args[:level].class == String
				@level = args[:level].intern
			elsif args[:level].class == Symbol
				@level = args[:level]
			else
				raise Puppet::DevError,
                    "Level is not a string or symbol: #{args[:level].class}"
			end

            # Just return unless we're actually at a level we should send
            #return unless self.class.sendlevel?(@level)

			@message = args[:message].to_s
			@time = Time.now
			# this should include the host name, and probly lots of other
			# stuff, at some point
			unless self.class.validlevel?(level)
				raise Puppet::DevError, "Invalid message level #{level}"
			end

            if args.include?(:tags)
                @tags = args[:tags]
            end

            if args.include?(:source)
                self.source = args[:source]
            else
                @source = "Puppet"
            end

            Log.newmessage(self)
		end

        # If they pass a source in to us, we make sure it is a string, and
        # we retrieve any tags we can.
        def source=(source)
            # We can't store the actual source, we just store the path.  This
            # is a bit of a stupid hack, specifically testing for elements, but
            # eh.
            if source.is_a?(Puppet::Element) and source.respond_to?(:path)
                @source = source.path
            else
                @source = source.to_s
            end
            unless defined? @tags and @tags
                if source.respond_to?(:tags)
                    @tags = source.tags
                end
            end
        end

        def tagged?(tag)
            @tags.include?(tag)
        end

		def to_report
            "%s %s (%s): %s" % [self.time, self.source, self.level, self.to_s]
		end

		def to_s
            return @message
		end
	end
end

# $Id$
