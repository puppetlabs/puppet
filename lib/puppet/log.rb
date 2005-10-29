require 'syslog'

module Puppet # :nodoc:
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

		@colors = {
			:debug => SLATE,
			:info => GREEN,
			:notice => PINK,
			:warning => ORANGE,
			:err => YELLOW,
            :alert => BLUE,
            :emerg => RESET,
            :crit => RESET
		}

        @destinations = {:syslog => Syslog.open("puppet")}

        # Reset all logs to basics.  Basically just closes all files and undefs
        # all of the other objects.
        def Log.close(dest = nil)
            if dest
                if @destinations.include?(dest)
                    Puppet.warning "Closing %s" % dest
                    if @destinations.respond_to?(:close)
                        @destinations[dest].close
                    end
                    @destinations.delete(dest)
                end
            else
                @destinations.each { |type, dest|
                    if dest.respond_to?(:flush)
                        dest.flush
                    end
                    if dest.respond_to?(:close)
                        dest.close
                    end
                }
                @destinations = {}
            end

            Puppet.info "closed"
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
            if @levels.index(hash[:level]) >= @loglevel 
                return Puppet::Log.new(hash)
            else
                return nil
            end
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

        # Create a new log destination.
        def Log.newdestination(dest)
            # Each destination can only occur once.
            if @destinations.include?(dest)
                return
            end

            case dest
            when "syslog", :syslog
                if Syslog.opened?
                    Syslog.close
                end
                @destinations[:syslog] = Syslog.open("puppet")
            when /^\// # files
                Puppet.info "opening %s as a log" % dest
                # first make sure the directory exists
                unless FileTest.exist?(File.dirname(dest))
                    begin
                        Puppet.recmkdir(File.dirname(dest))
                        Puppet.info "Creating log directory %s" %
                            File.dirname(dest)
                    rescue => detail
                        Log.destination = :console
                        Puppet.err "Could not create log directory: %s" %
                            detail
                        return
                    end
                end

                begin
                    # create the log file, if it doesn't already exist
                    file = File.open(dest,File::WRONLY|File::CREAT|File::APPEND)
                rescue => detail
                    Log.destination = :console
                    Puppet.err "Could not create log file: %s" %
                        detail
                    return
                end
                @destinations[dest] = file
            when "console", :console
                @destinations[:console] = :console
            when Puppet::Server::Logger
                @destinations[dest] = dest
            else
                Puppet.info "Treating %s as a hostname" % dest
                args = {}
                if dest =~ /:(\d+)/
                    args[:Port] = $1
                    args[:Server] = dest.sub(/:\d+/, '')
                else
                    args[:Server] = dest
                end
                @destinations[dest] = Puppet::Client::LogClient.new(args)
            end
        end

        # Route the actual message. FIXME There are lots of things this method should
        # do, like caching, storing messages when there are not yet destinations,
        # a bit more.
        # It's worth noting that there's a potential for a loop here, if
        # the machine somehow gets the destination set as itself.
        def Log.newmessage(msg)
            @destinations.each { |type, dest|
                case dest
                when Module # This is the Syslog module
                    next if msg.remote
                    # XXX Syslog currently has a bug that makes it so you
                    # cannot log a message with a '%' in it.  So, we get rid
                    # of them.
                    if msg.source == "Puppet"
                        dest.send(msg.level, msg.to_s.gsub("%", '%%'))
                    else
                        dest.send(msg.level, "(%s) %s" %
                            [msg.source.to_s.gsub("%", ""), msg.to_s.gsub("%", '%%')]
                        )
                    end
                when File:
                    dest.puts("%s %s (%s): %s" %
                        [msg.time, msg.source, msg.level, msg.to_s])
                when :console
                    if msg.source == "Puppet"
                        puts @colors[msg.level] + "%s: %s" % [
                            msg.level, msg.to_s
                        ] + RESET
                    else
                        puts @colors[msg.level] + "%s (%s): %s" % [
                            msg.source, msg.level, msg.to_s
                        ] + RESET
                    end
                when Puppet::Client::LogClient
                    unless msg.is_a?(String) or msg.remote
                        begin
                            #puts "would have sent %s" % msg
                            #puts "would have sent %s" %
                            #    CGI.escape(Marshal::dump(msg))
                            begin
                                tmp = CGI.escape(Marshal::dump(msg))
                            rescue => detail
                                puts "Could not dump: %s" % detail.to_s
                                return
                            end
                            dest.addlog(tmp)
                            #dest.addlog(msg.to_s)
                            sleep(0.5)
                        rescue => detail
                            Puppet.err detail
                            @destinations.delete(type)
                        end
                    end
                else
                    raise Puppet::Error, "Invalid log destination %s" % dest
                    #puts "Invalid log destination %s" % dest.inspect
                end
            }
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

		attr_accessor :level, :message, :source, :time, :tags, :remote

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
			@message = args[:message]
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
                # We can't store the actual source, we just store the path
                if args[:source].respond_to?(:path)
                    @source = args[:source].path
                else
                    @source = args[:source].to_s
                end
                unless defined? @tags and @tags
                    if args[:source].respond_to?(:tags)
                        @tags = args[:source].tags
                    end
                end
            else
                @source = "Puppet"
            end

            Log.newmessage(self)
		end

		def to_s
            return @message
		end
	end
end

# $Id$
