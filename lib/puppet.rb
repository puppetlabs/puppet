#!/usr/local/bin/ruby -w

# $Id$

require 'singleton'
require 'puppet/log'

# XXX see the bottom of the file for further inclusions

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
    @@config[:rrddir] = "/var/puppet/rrd"
    @@config[:rrdgraph] = false
    @@config[:logdir] = "/var/puppet/log"
    @@config[:logfile] = "/var/puppet/log/puppet.log"
    @@config[:statefile] = "/var/puppet/log/state"


    # handle the different message levels
    # XXX this should be redone to treat log-levels like radio buttons
    # pick one, and it and all above it will be logged
    Puppet::Log.levels.each { |level|
        define_method(level,proc { |args|
            Puppet::Log.create(level,args)
        })
        module_function level
        # default to enabling all notice levels except debug
        @@config[level] = true unless level == :notice
    }

    # set up our configuration
	def Puppet.init(args)
		args.each {|p,v|
			@@config[p] = v
		}
	end

	# configuration parameter access and stuff
	def Puppet.[](param)
		return @@config[param]
	end

	# configuration parameter access and stuff
	def Puppet.[]=(param,value)
		@@config[param] = value
        case param
        when :debug:
            if value
                Puppet::Log.level(:debug)
            else
                Puppet::Log.level(:notice)
            end
        when :loglevel:
            Puppet::Log.level(value)
        end
	end

end

require 'puppet/storage'
require 'puppet/type'
