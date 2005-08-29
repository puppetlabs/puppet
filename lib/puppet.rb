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
    PUPPETVERSION="0.9.0"

    def Puppet.version
        return PUPPETVERSION
    end

    class Error < RuntimeError
        attr_accessor :stack, :line, :file
        def initialize(message)
            @message = message

            @stack = caller
        end

        def to_s
            str = nil
            if defined? @file and defined? @line
                str = "%s at file %s, line %s" %
                    [@message, @file, @line]
            elsif defined? @line
                str = "%s at line %s" %
                    [@message, @line]
            else
                str = @message
            end

            #if Puppet[:debug] and @stack
            #    str += @stack.to_s
            #end

            return str
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
    # XXX this isn't actually working right now
    alias :error :err

    @defaults = {
        :rrddir         => [:puppetvar,      "rrd"],
        :logdir         => [:puppetvar,      "log"],
        :bucketdir      => [:puppetvar,      "bucket"],
        :statedir       => [:puppetvar,      "state"],

        # then the files},
        :manifest       => [:puppetconf,     "manifest.pp"],
        :localconfig    => [:puppetconf,     "localconfig.ma"],
        :logfile        => [:logdir,         "puppet.log"],
        :httplogfile    => [:logdir,         "http.log"],
        :masterlog      => [:logdir,         "puppetmaster.log"],
        :masterhttplog  => [:logdir,         "masterhttp.log"],
        :checksumfile   => [:statedir,       "checksums"],
        :ssldir         => [:puppetconf,     "ssl"],

        # and finally the simple answers,
        :server         => "puppet",
        :rrdgraph       => false,
        :noop           => false,
        :parseonly      => false,
        :puppetport     => 8139,
        :masterport     => 8140,
        :loglevel       => :notice,
        :logdest        => :file,
    }
    if Process.uid == 0
        @defaults[:puppetconf] = "/etc/puppet"
        @defaults[:puppetvar] = "/var/puppet"
    else
        @defaults[:puppetconf] = File.expand_path("~/.puppet")
        @defaults[:puppetvar] = File.expand_path("~/.puppet/var")
    end

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
            # allow manual override
            if @@config.include?(param)
                return @@config[param]
            else
                if @defaults.include?(param)
                    default = @defaults[param]
                    if default.is_a?(Proc)
                        return default.call()
                    elsif default.is_a?(Array)
                        return File.join(self[default[0]], default[1])
                    else
                        return default
                    end
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

    def self.setdefault(param,value)
        if value.is_a?(Array) 
            if value[0].is_a?(Symbol) 
                unless @defaults.include?(value[0])
                    raise ArgumentError, "Unknown basedir %s for param %s" %
                        [value[0], param]
                end
            else
                raise ArgumentError, "Invalid default %s for param %s" %
                    [value.inspect, param]
            end

            unless value[1].is_a?(String)
                raise ArgumentError, "Invalid default %s for param %s" %
                    [value.inspect, param]
            end

            unless value.length == 2
                raise ArgumentError, "Invalid default %s for param %s" %
                    [value.inspect, param]
            end

            @defaults[param] = value
        else
            @defaults[param] = value
        end
    end

    # XXX this should all be done using puppet objects, not using
    # normal mkdir
    def self.recmkdir(dir,mode = 0755)
        if FileTest.exist?(dir)
            return false
        else
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
            return true
        end
    end
end

require 'puppet/server'
require 'puppet/type'
require 'puppet/storage'
