#!/usr/local/bin/ruby -w

# $Id$

require 'singleton'

# XXX see the bottom of the file for further inclusions

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
module Puppet
    # the hash that determines how our system behaves
    @@config = Hash.new(false)

    @@config[:puppetroot] = "/var/puppet"
    @@config[:logdir] = "/var/puppet/log"
    @@config[:logfile] = "/var/puppet/log/puppet.log"
    @@config[:statefile] = "/var/puppet/log/state"


    loglevels = [:debug,:verbose,:notice,:warning,:error]

    # handle the different message levels
    # XXX this should be redone to treat log-levels like radio buttons
    # pick one, and it and all above it will be logged
    loglevels.each { |level|
        define_method(level,proc { |args|
            Puppet.message(level,args)
        })
        module_function level
        # default to enabling all notice levels except debug
        @@config[level] = true unless level == :debug
    }

	def Puppet.message(level,*ary)
		msg = ary.join(" ")

		if @@config[level]
			Puppet::Message.new(
				:level => level,
				:source => "Puppet",
				:message => msg
			)
		end
	end

    # set up our configuration
	def Puppet.init(args)
		args.each {|p,v|
			@@config[p] = v
		}
	end

    # just print any messages we get
    # we should later behave differently depending on the message
	def Puppet.newmessage(msg)
		puts msg
	end

	# configuration parameter access and stuff
	def Puppet.[](param)
		return @@config[param]
	end

	# configuration parameter access and stuff
	def Puppet.[]=(param,value)
		@@config[param] = value
	end

end

require 'puppet/storage'
require 'puppet/message'
require 'puppet/type'
