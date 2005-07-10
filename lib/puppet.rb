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

    @@config[:rrdgraph] = false
    if Process.uid == 0
        @@config[:puppetroot] = "/var/puppet"
    else
        @@config[:puppetroot] = File.expand_path("~/.puppet")
    end
    @@config[:rrddir] = File.join(@@config[:puppetroot],"rrd")
    @@config[:logdir] = File.join(@@config[:puppetroot],"log")
    @@config[:logfile] = File.join(@@config[:puppetroot],"log/puppet.log")
    @@config[:statefile] = File.join(@@config[:puppetroot],"log/state")

    # handle the different message levels
    # XXX this should be redone to treat log-levels like radio buttons
    # pick one, and it and all above it will be logged
    Puppet::Log.levels.each { |level|
        define_method(level,proc { |args|
            Puppet::Log.create(level,args)
        })
        module_function level
    #    # default to enabling all notice levels except debug
    #    @@config[level] = true unless level == :notice
    }

    # set up our configuration
	#def Puppet.init(args)
	#	args.each {|p,v|
	#		@@config[p] = v
	#	}
	#end

	# configuration parameter access and stuff
	def Puppet.[](param)
        case param
        when :debug:
            if Puppet::Log.level == :debug
                return true
            else
                return false
            end
        when :loglevel:
            return Puppet::Log.level
        when :logdest:
            return Puppet::Log.destination
        else
            return @@config[param]
        end
	end

	# configuration parameter access and stuff
	def Puppet.[]=(param,value)
        case param
        when :debug:
            if value
                Puppet::Log.level=(:debug)
            else
                Puppet::Log.level=(:notice)
            end
        when :loglevel:
            Puppet::Log.level=(value)
        when :logdest:
            Puppet::Log.destination=(value)
        else
            @@config[param] = value
        end
	end

end

require 'puppet/storage'
require 'puppet/type'
