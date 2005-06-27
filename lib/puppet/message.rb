# $Id$

module Puppet
    #------------------------------------------------------------
    # provide feedback of various types to the user
    # modeled after syslog messages
    # each level of message prints in a different color
	class Message
		@@messages = Array.new
		@@levels = [ :debug, :verbose, :notice, :warning, :error ]
		@@colors = {
			:debug => SLATE,
			:verbose => ORANGE,
			:notice => PINK,
			:warning => GREEN,
			:error => YELLOW
		}

		attr_accessor :level, :message, :source

        def Message.loglevels
            return @@levels
        end

		def initialize(args)
			unless args.include?(:level) && args.include?(:message) &&
						args.include?(:source) 
				raise "Puppet::Message called incorrectly"
			end

			if args[:level].class == String
				@level = args[:level].intern
			elsif args[:level].class == Symbol
				@level = args[:level]
			else
				raise "Level is not a string or symbol: #{args[:level].class}"
			end
			@message = args[:message]
			@source = args[:source]
			@time = Time.now
			# this should include the host name, and probly lots of other
			# stuff, at some point
			unless @@levels.include?(level)
				raise "Invalid message level #{level}"
			end

			@@messages.push(self)
			Puppet.newmessage(self)
		end

		def to_s
			# this probably won't stay, but until this leaves the console,
			# i'm going to use coloring...
			#return "#{@time} #{@source} (#{@level}): #{@message}"
			#return @@colors[@level] + "%s %s (%s): %s" % [
			#	@time, @source, @level, @message
			#] + RESET
			return @@colors[@level] + "%s (%s): %s" % [
				@source, @level, @message
			] + RESET
		end
	end
    #------------------------------------------------------------
end
