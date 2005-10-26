# $Id$

require 'syslog'

module Puppet
    #------------------------------------------------------------
    # provide feedback of various types to the user
    # modeled after syslog messages
    # each level of message prints in a different color
	class Log
        PINK="[0;31m"
        GREEN="[0;32m"
        YELLOW="[0;33m"
        SLATE="[0;34m"
        ORANGE="[0;35m"
        BLUE="[0;36m"
        RESET="[0m"

		@@messages = Array.new

        @@levels = [:debug,:info,:notice,:warning,:err,:alert,:emerg,:crit]
        @@loglevel = 2
        @@logdest = :console

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

        def Log.close
            if defined? @@logfile
                @@logfile.close
                @@logfile = nil
            end

            if defined? @@syslog
                @@syslog = nil
            end
        end

        def Log.flush
            if defined? @@logfile
                @@logfile.flush
            end
        end

        def Log.create(level,*ary)
            msg = ary.join(" ")

            if @@levels.index(level) >= @@loglevel 
                return Puppet::Log.new(
                    :level => level,
                    :source => "Puppet",
                    :message => msg
                )
            else
                return nil
            end
        end

        def Log.levels
            return @@levels.dup
        end

        def Log.destination
            return @@logdest
        end

        def Log.destination=(dest)
            if dest == "syslog" or dest == :syslog
                unless defined? @@syslog
                    @@syslog = Syslog.open("puppet")
                end
                @@logdest = :syslog
            elsif dest =~ /^\//
                if defined? @@logfile and @@logfile
                    @@logfile.close
                end

                @@logpath = dest

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

                Puppet[:logfile] = dest
                begin
                    # create the log file, if it doesn't already exist
                    @@logfile = File.open(dest,File::WRONLY|File::CREAT|File::APPEND)
                rescue => detail
                    Log.destination = :console
                    Puppet.err "Could not create log file: %s" %
                        detail
                    return
                end
                @@logdest = :file
            else
                unless @@logdest == :console or @@logdest == "console"
                    Puppet.notice "Invalid log setting %s; setting log destination to 'console'" % @@logdest
                end
                @@logdest = :console
            end
        end

        def Log.level
            return @@levels[@@loglevel]
        end

        def Log.level=(level)
            unless level.is_a?(Symbol)
                level = level.intern
            end

            unless @@levels.include?(level)
                raise Puppet::DevError, "Invalid loglevel %s" % level
            end

            @@loglevel = @@levels.index(level)
        end

        def Log.newmessage(msg)
            case @@logdest
            when :syslog:
                if msg.source == "Puppet"
                    @@syslog.send(msg.level,msg.to_s)
                else
                    @@syslog.send(msg.level,"(%s) %s" % [msg.source,msg.to_s])
                end
            when :file:
                unless defined? @@logfile
                    raise Puppet::DevError,
                        "Log file must be defined before we can log to it"
                end
                @@logfile.puts("%s %s (%s): %s" %
                    [msg.time,msg.source,msg.level,msg.to_s])
            else
                if msg.source == "Puppet"
                    puts @@colors[msg.level] + "%s: %s" % [
                        msg.level, msg.to_s
                    ] + RESET
                else
                    puts @@colors[msg.level] + "%s (%s): %s" % [
                        msg.source, msg.level, msg.to_s
                    ] + RESET
                end
            end
        end

        def Log.reopen
            if @@logfile
                Log.destination = @@logpath
            end
        end

		attr_accessor :level, :message, :source, :time, :tags, :path

		def initialize(args)
			unless args.include?(:level) && args.include?(:message) &&
						args.include?(:source) 
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
			@source = args[:source] || "Puppet"
			@time = Time.now
			# this should include the host name, and probly lots of other
			# stuff, at some point
			unless @@levels.include?(level)
				raise Puppet::DevError, "Invalid message level #{level}"
			end

            if args.include?(:tags)
                @tags = args[:tags]
            end

            if args.include?(:path)
                @path = args[:path]
            end

            Log.newmessage(self)
		end

		def to_s
			# this probably won't stay, but until this leaves the console,
			# i'm going to use coloring...
			#return "#{@time} #{@source} (#{@level}): #{@message}"
			#return @@colors[@level] + "%s %s (%s): %s" % [
			#	@time, @source, @level, @message
			#] + RESET
            return @message
			#return @@colors[@level] + "%s (%s): %s" % [
			#	@source, @level, @message
			#] + RESET
		end
	end
    #------------------------------------------------------------
end
