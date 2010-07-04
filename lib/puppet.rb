# Try to load rubygems.  Hey rubygems, I hate you.
begin
    require 'rubygems'
rescue LoadError
end

# see the bottom of the file for further inclusions
require 'singleton'
require 'facter'
require 'puppet/error'
require 'puppet/util'
require 'puppet/util/log'
require 'puppet/util/autoload'
require 'puppet/util/settings'
require 'puppet/util/feature'
require 'puppet/util/suidmanager'

#------------------------------------------------------------
# the top-level module
#
# all this really does is dictate how the whole system behaves, through
# preferences for things like debugging
#
# it's also a place to find top-level commands like 'debug'

module Puppet
    PUPPETVERSION = '0.25.5'

    def Puppet.version
        return PUPPETVERSION
    end

    class << self
        include Puppet::Util
        attr_reader :features
        attr_writer :name
    end

    # the hash that determines how our system behaves
    @@settings = Puppet::Util::Settings.new

    # The services running in this process.
    @services ||= []

    # define helper messages for each of the message levels
    Puppet::Util::Log.eachlevel { |level|
        define_method(level,proc { |args|
            if args.is_a?(Array)
                args = args.join(" ")
            end
            Puppet::Util::Log.create(
                :level => level,
                :message => args
            )
        })
        module_function level
    }

    # I keep wanting to use Puppet.error
    # XXX this isn't actually working right now
    alias :error :err

    # The feature collection
    @features = Puppet::Util::Feature.new('puppet/feature')

    # Load the base features.
    require 'puppet/feature/base'

    # Store a new default value.
    def self.setdefaults(section, hash)
        @@settings.setdefaults(section, hash)
    end

    # configuration parameter access and stuff
    def self.[](param)
        case param
        when :debug
            if Puppet::Util::Log.level == :debug
                return true
            else
                return false
            end
        else
            return @@settings[param]
        end
    end

    # configuration parameter access and stuff
    def self.[]=(param,value)
        @@settings[param] = value
    end

    def self.clear
        @@settings.clear
    end

    def self.debug=(value)
        if value
            Puppet::Util::Log.level=(:debug)
        else
            Puppet::Util::Log.level=(:notice)
        end
    end

    def self.settings
        @@settings
    end

    # Load all of the configuration parameters.
    require 'puppet/defaults'

    def self.genmanifest
        if Puppet[:genmanifest]
            puts Puppet.settings.to_manifest
            exit(0)
        end
    end

    # Parse the config file for this process.
    def self.parse_config
        Puppet.settings.parse
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
                    begin
                        Dir.mkdir(File.join(path), mode)
                    rescue Errno::EACCES => detail
                        Puppet.err detail.to_s
                        return false
                    rescue => detail
                        Puppet.err "Could not create %s: %s" % [path, detail.to_s]
                        return false
                    end
                elsif FileTest.directory?(File.join(path))
                    next
                else FileTest.exist?(File.join(path))
                    raise Puppet::Error, "Cannot create %s: basedir %s is a file" %
                        [dir, File.join(path)]
                end
            }
            return true
        end
    end

    # Create a new type.  Just proxy to the Type class.
    def self.newtype(name, options = {}, &block)
        Puppet::Type.newtype(name, options, &block)
    end

    # Retrieve a type by name.  Just proxy to the Type class.
    def self.type(name)
        # LAK:DEP Deprecation notice added 12/17/2008
        Puppet.warning "Puppet.type is deprecated; use Puppet::Type.type"
        Puppet::Type.type(name)
    end
end

require 'puppet/type'
require 'puppet/network'
require 'puppet/ssl'
require 'puppet/module'
require 'puppet/util/storage'
require 'puppet/parser/interpreter'

if Puppet[:storeconfigs]
    require 'puppet/rails'
end

