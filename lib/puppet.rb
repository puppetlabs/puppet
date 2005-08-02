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
#    if Process.uid == 0
#        PUPPETCONF = "/etc/puppet"
#        PUPPETVAR = "/var/puppet"
#    else
#        PUPPETCONF = File.expand_path("~/.puppet")
#        PUPPETVAR = File.expand_path("~/.puppet/var")
#    end
#
#    CERTDIR = File.join(PUPPETCONF, "certs")
#    CERTFILE = File.join(CERTDIR, "localhost.crt")
#    CERTKEY = File.join(CERTDIR, "localhost.key")
#
#    RRDDIR = File.join(PUPPETROOT,  "rrd")
#    LOGDIR = File.join(PUPPETROOT,  "log")
#    LOGFILE = File.join(LOGDIR,  "puppet.log")
#
#    STATEDIR = File.join(PUPPETROOT,  "state")
#    CHECKSUMFILE = File.join(STATEDIR,  "checksums")
#
    class Error < RuntimeError
        attr_accessor :stack, :line, :file
        def initialize(message)
            @message = message

            @stack = caller
        end

        def to_s
            if @file and @line
                return "%s at file %s, line %s" %
                    [@message, @file, @line]
            else
                return @message
            end
        end
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
        if param.is_a?(String)
            param = param.intern
        elsif ! param.is_a?(Symbol)
            raise ArgumentError, "Invalid parameter type %s" % param.class
        end
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
            if @@config.include?(param)
                return @@config[param]
            else
                # here's where we define our defaults
                returnval = case param
                when :puppetconf:
                    if Process.uid == 0
                        "/etc/puppet"
                    else
                        File.expand_path("~/.puppet/var")
                    end
                when :puppetvar:
                    if Process.uid == 0
                        "/var/puppet"
                    else
                        File.expand_path("~/.puppet")
                    end
                when :rrdgraph:     false
                when :noop:         false
                when :puppetport:   8139
                when :masterport:   8140
                when :rrddir:       File.join(self[:puppetvar],     "rrd")
                when :logdir:       File.join(self[:puppetvar],     "log")
                when :bucketdir:    File.join(self[:puppetvar],     "bucket")
                when :logfile:      File.join(self[:logdir],        "puppet.log")
                when :statedir:     File.join(self[:puppetvar],     "state")
                when :checksumfile: File.join(self[:statedir],      "checksums")
                when :certdir:      File.join(self[:puppetconf],    "certs")
                when :localcert:    File.join(self[:certdir],       "localhost.crt")
                when :localkey:     File.join(self[:certdir],       "localhost.key")
                when :localpub:     File.join(self[:certdir],       "localhost.pub")
                when :mastercert:   File.join(self[:certdir],       "puppetmaster.crt")
                when :masterkey:    File.join(self[:certdir],       "puppetmaster.key")
                when :masterpub:    File.join(self[:certdir],       "puppetmaster.pub")
                else
                    raise ArgumentError, "Invalid parameter %s" % param
                end
            end
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
end

require 'puppet/type'
require 'puppet/storage'
