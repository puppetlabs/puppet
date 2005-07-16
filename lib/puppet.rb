#!/usr/local/bin/ruby -w

# $Id$

require 'singleton'
require 'puppet/log'

# see the bottom of the file for further inclusions

#------------------------------------------------------------
# the top-level module
#
# all this really does is dictate how the whole system behaves, through
# preferences for things like debugging
#
# it's also a place to find top-level commands like 'debug'
module Puppet
    class Error < RuntimeError
        attr_accessor :stack
    end

    class DevError < Error; end

    # the hash that determines how our system behaves
    @@config = Hash.new(false)

    # define helper messages for each of the message levels
    Puppet::Log.levels.each { |level|
        define_method(level,proc { |args|
            Puppet::Log.create(level,args)
        })
        module_function level
    }

    # I keep wanting to use Puppet.error
    alias :error :err

	# configuration parameter access and stuff
	def self.[](param)
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
	def self.[]=(param,value)
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

    def self.recmkdir(dir,mode = 0755)
        tmp = dir.sub(/^\//,'')
        path = [File::SEPARATOR]
        tmp.split(File::SEPARATOR).each { |dir|
            path.push dir
            if ! FileTest.exist?(File.join(path))
                Dir.mkdir(File.join(path), mode)
            elsif FileTest.directory?(File.join(path))
                next
            else FileTest.exist?(File.join(path))
                raise "Cannot create %s: basedir %s is a file" %
                    [dir, File.join(path)]
            end
        }
    end

    self[:rrdgraph] = false
    if Process.uid == 0
        self[:puppetroot] = "/var/puppet"
    else
        self[:puppetroot] = File.expand_path("~/.puppet")
    end

    self[:rrddir] = File.join(self[:puppetroot],"rrd")
    self[:logdir] = File.join(self[:puppetroot],"log")
    self[:logfile] = File.join(self[:puppetroot],"log/puppet.log")
    self[:statefile] = File.join(self[:puppetroot],"log/state")
end

require 'puppet/type'
require 'puppet/storage'
