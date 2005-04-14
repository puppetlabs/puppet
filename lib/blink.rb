#!/usr/local/bin/ruby -w

# $Id$

require 'singleton'
require 'blink/component'
require 'blink/interface'
require 'blink/selector'
require 'blink/objects'
require 'blink/objects/service'
require 'blink/objects/file'
require 'blink/objects/symlink'

PINK="[0;31m"
GREEN="[0;32m"
YELLOW="[0;33m"
SLATE="[0;34m"
ORANGE="[0;35m"
BLUE="[0;36m"
RESET="[0m"

#------------------------------------------------------------
# the top-level module
#
# all this really does is dictate how the whole system behaves, through
# preferences for things like debugging
#
# it's also a place to find top-level commands like 'debug'
module Blink
    # the hash that determines how our system behaves
    @@config = Hash.new(false)


    msglevels = [:debug,:verbose,:notice,:warning,:error]

    # handle the different message levels
    msglevels.each { |level|
        define_method(level,proc { |args|
            Blink.message(level,args)
        })
        module_function level
        # default to enabling all notice levels except debug
        @@config[level] = true unless level == :debug
    }

	def Blink.message(level,ary)
		msg = ""
		if ary.class == String
			msg = ary
		else
			msg = ary.join(" ")
		end

		if @@config[level]
			Blink::Message.new(
				:level => level,
				:source => "Blink",
				:message => msg
			)
		end
	end

    # set up our configuration
	def Blink.init(args)
		args.each {|p,v|
			@@config[p] = v
		}
	end

    # just print any messages we get
    # we should later behave differently depending on the message
	def Blink.newmessage(msg)
		puts msg
	end

    # DISABLED

	# we've collected all data; now operate on it
#	def Blink.run
#		ops = Blink::Objects.genops()
#		ops.find_all { |op|
#			op.auto?()
#		}.each { |op|
#			Blink::Message.new(
#				:level => :debug,
#				:source => "Blink",
#				:message => "Running op %s" % op
#			)
#			op.check
#		}.find_all { |op|
#			puts "dirty? #{op}"
#			op.dirty?
#		}.collect { |op|
#			puts "%s is dirty; %s instead of %s" % [op, op.state, op.should]
#			op.fix
#		}.each { |event| # this might need to support lists someday...
#			#list.each { |event|
#				puts event
#				event.trigger
#			#}
#		}
#	end
#
#	def Blink.walk
#		root = Blink::Objects.root
#		root.check
#		if root.dirty?
#			Blink::Message.new(
#				:message => "someone's dirty",
#				:level => :notice,
#				:source => root
#			)
#			root.fix
#		end
#	end

	# configuration parameter access and stuff
	def Blink.[](param)
		return @@config[param]
	end

	# configuration parameter access and stuff
	def Blink.[]=(param,value)
		@@config[param] = value
	end

    # a simple class for creating callbacks
	class Event
		attr_reader :event, :object
		attr_writer :event, :object

		def initialize(args)
			@event = args[:event]
			@object = args[:object]

			if @event.nil? or @object.nil?
				raise "Event.new called incorrectly"
			end
		end

		def trigger
			@object.trigger(@event)
		end
	end

    # a class for storing state
    # not currently used
	class State
		include Singleton
		@@config = "/var/tmp/blinkstate"
		@@state = Hash.new
		@@splitchar = " "
		
		def initialize
			self.load
		end

		def State.load
			puts "loading state"
			return unless File.exists?(@@config)
			File.open(@@config) { |file|
				file.gets { |line|
					myclass, key, value = line.split(@@splitchar)

					unless defined? @@state[myclass]
						@@state[myclass] = Hash.new
					end

					@@state[myclass][key] = value
				}
			}
		end

		def State.state(myclass)
			unless defined? @@state[myclass]
				@@state[myclass] = Hash.new
			end
			return @@state[myclass]
		end

		def State.store
			File.open(@@config, File::CREAT|File::WRONLY, 0644) { |file|
				@@state.each { |key, value|
					file.puts([self.class,key,value].join(@@splitchar))
				}
			}
		end
	end

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

		attr_reader :level, :message
		attr_writer :level, :message

		def initialize(args)
			unless args.include?(:level) && args.include?(:message) &&
						args.include?(:source) 
				raise "Blink::Message called incorrectly"
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
			Blink.newmessage(self)
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
