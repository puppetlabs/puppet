# Try to load rubygems.  Hey rubygems, I hate you.
begin
    require 'rubygems'
rescue LoadError
end

# see the bottom of the file for further inclusions
require 'singleton'
require 'facter'
require 'puppet/error'
require 'puppet/external/event-loop'
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
    PUPPETVERSION = '0.24.9'

    def Puppet.version
        return PUPPETVERSION
    end

    class << self
        # So we can monitor signals and such.
        include SignalObserver

        include Puppet::Util

        # To keep a copy of arguments.  Set within Config#addargs, because I'm
        # lazy.
        attr_accessor :args
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
        when :debug:
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

    # Run all threads to their ends
    def self.join
        defined? @threads and @threads.each do |t| t.join end
    end

    # Create a new service that we're supposed to run
    def self.newservice(service)
        @services ||= []

        @services << service
    end

    def self.newthread(&block)
        @threads ||= []

        @threads << Thread.new do
            yield
        end
    end

    def self.newtimer(hash, &block)
        timer = nil
        threadlock(:timers) do
            @timers ||= []
            timer = EventLoop::Timer.new(hash)
            @timers << timer

            if block_given?
                observe_signal(timer, :alarm, &block)
            end
        end

        # In case they need it for something else.
        timer
    end

    # Parse the config file for this process.
    def self.parse_config(oldconfig = nil)
        # First look for the old configuration file.
        oldconfig ||= File.join(Puppet[:confdir], Puppet[:name].to_s + ".conf")
        if FileTest.exists?(oldconfig) and Puppet[:name] != "puppet"
            Puppet.warning "Individual config files are deprecated; remove %s and use puppet.conf" % oldconfig
            Puppet.settings.old_parse(oldconfig)
            return
        end

        # Now check for the normal config.
        if Puppet[:config] and File.exists? Puppet[:config]
            Puppet.debug "Parsing %s" % Puppet[:config]
            Puppet.settings.parse(Puppet[:config])
        end
    end

    # Relaunch the executable.
    def self.restart
        command = $0 + " " + self.args.join(" ")
        Puppet.notice "Restarting with '%s'" % command
        Puppet.shutdown(false)
        Puppet::Util::Log.reopen
        exec(command)
    end

    # Trap a couple of the main signals.  This should probably be handled
    # in a way that anyone else can register callbacks for traps, but, eh.
    def self.settraps
        [:INT, :TERM].each do |signal|
            trap(signal) do
                Puppet.notice "Caught #{signal}; shutting down"
                Puppet.debug "Signal caught here:"
                caller.each { |l| Puppet.debug l }
                Puppet.shutdown
            end
        end

        # Handle restarting.
        trap(:HUP) do
            if client = @services.find { |s| s.is_a? Puppet::Network::Client.master } and client.running?
                client.restart
            else
                Puppet.restart
            end
        end

        # Provide a hook for running clients where appropriate
        trap(:USR1) do
            done = 0
            Puppet.notice "Caught USR1; triggering client run"
            @services.find_all { |s| s.is_a? Puppet::Network::Client }.each do |client|
                if client.respond_to? :running?
                    if client.running?
                        Puppet.info "Ignoring running %s" % client.class
                    else
                        done += 1
                        begin
                            client.runnow
                        rescue => detail
                            Puppet.err "Could not run client: %s" % detail
                        end
                    end
                else
                    Puppet.info "Ignoring %s; cannot test whether it is running" %
                        client.class
                end
            end

            unless done > 0
                Puppet.notice "No clients were run"
            end
        end

        trap(:USR2) do
            Puppet::Util::Log.reopen
        end
    end

    # Shutdown our server process, meaning stop all services and all threads.
    # Optionally, exit.
    def self.shutdown(leave = true)
        Puppet.notice "Shutting down"
        # Unmonitor our timers
        defined? @timers and @timers.each do |timer|
            EventLoop.current.ignore_timer timer
        end

        # This seems to exit the process, although I can't find where it does
        # so.  Leaving it out doesn't seem to hurt anything.
        #if EventLoop.current.running?
        #    EventLoop.current.quit
        #end

        # Stop our services
        defined? @services and @services.each do |svc|
            next unless svc.respond_to?(:shutdown)
            begin
                timeout(20) do
                    svc.shutdown
                end
            rescue TimeoutError
                Puppet.err "%s could not shut down within 20 seconds" % svc.class
            end
        end

        # And wait for them all to die, giving a decent amount of time
        defined? @threads and @threads.each do |thr|
            begin
                timeout(20) do
                    thr.join
                end
            rescue TimeoutError
                # Just ignore this, since we can't intelligently provide a warning
            end
        end

        if leave
            exit(0)
        end
    end

    # Start all of our services and optionally our event loop, which blocks,
    # waiting for someone, somewhere, to generate events of some kind.
    def self.start(block = true)
        # Starting everything in its own thread, fwiw
        defined? @services and @services.dup.each do |svc|
            newthread do
                begin
                    svc.start
                rescue => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    @services.delete svc
                    Puppet.err "Could not start %s: %s" % [svc.class, detail]
                end
            end
        end

        # We need to give the services a chance to register their timers before
        # we try to start monitoring them.
        sleep 0.5

        unless @services.length > 0
            Puppet.notice "No remaining services; exiting"
            exit(1)
        end

        if defined? @timers and ! @timers.empty?
            @timers.each do |timer|
                EventLoop.current.monitor_timer timer
            end
        end

        if block
            EventLoop.current.run
        end
    end

    # Create the timer that our different objects (uh, mostly the client)
    # check.
    def self.timer
        unless defined? @timer
            #Puppet.info "Interval is %s" % Puppet[:runinterval]
            #@timer = EventLoop::Timer.new(:interval => Puppet[:runinterval])
            @timer = EventLoop::Timer.new(
                :interval => Puppet[:runinterval],
                :tolerance => 1,
                :start? => true
            )
            EventLoop.current.monitor_timer @timer
        end
        @timer
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
        Puppet::Type.type(name)
    end
end

require 'puppet/type'
require 'puppet/network'
require 'puppet/module'
require 'puppet/util/storage'
require 'puppet/parser/interpreter'
if Puppet[:storeconfigs]
    require 'puppet/rails'
end

