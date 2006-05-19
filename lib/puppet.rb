require 'singleton'
require 'puppet/event-loop'
require 'puppet/log'
require 'puppet/config'
require 'puppet/util'

# see the bottom of the file for further inclusions

#------------------------------------------------------------
# the top-level module
#
# all this really does is dictate how the whole system behaves, through
# preferences for things like debugging
#
# it's also a place to find top-level commands like 'debug'
module Puppet
    PUPPETVERSION = '0.17.2'

    def Puppet.version
        return PUPPETVERSION
    end

    # So we can monitor signals and such.
    class << self
        include SignalObserver
    end

    class Error < RuntimeError
        attr_accessor :stack, :line, :file
        attr_writer :backtrace

        def backtrace
            if defined? @backtrace
                return @backtrace
            else
                return super
            end
        end

        def initialize(message)
            @message = message
        end

        def to_s
            str = nil
            if defined? @file and defined? @line and @file and @line
                str = "%s in file %s at line %s" %
                    [@message.to_s, @file, @line]
            elsif defined? @line and @line
                str = "%s at line %s" %
                    [@message.to_s, @line]
            else
                str = @message.to_s
            end

            return str
        end
    end

    class DevError < Error; end

    def self.name
        unless defined? @name
            @name = $0.gsub(/.+#{File::SEPARATOR}/,'').sub(/\.rb$/, '')
        end

        return @name
    end

    # the hash that determines how our system behaves
    @@config = Puppet::Config.new

    # define helper messages for each of the message levels
    Puppet::Log.eachlevel { |level|
        define_method(level,proc { |args|
            if args.is_a?(Array)
                args = args.join(" ")
            end
            Puppet::Log.create(
                :level => level,
                :message => args
            )
        })
        module_function level
    }

    # I keep wanting to use Puppet.error
    # XXX this isn't actually working right now
    alias :error :err

    # Store a new default value.
    def self.setdefaults(section, hash)
        @@config.setdefaults(section, hash)
    end

    # If we're running the standalone puppet process as a non-root user,
    # use basedirs that are in the user's home directory.
    conf = nil
    var = nil
    if self.name == "puppet" and Process.uid != 0
        conf = File.expand_path("~/.puppet")
        var = File.expand_path("~/.puppet/var")
    else
        # Else, use system-wide directories.
        conf = "/etc/puppet"
        var = "/var/puppet"
    end

    self.setdefaults(:puppet,
        :confdir => [conf, "The main Puppet configuration directory."],
        :vardir => [var, "Where Puppet stores dynamic and growing data."]
    )

    if self.name == "puppetmasterd"
        self.setdefaults(:puppetmasterd,
            :logdir => {:default => "$vardir/log",
                :mode => 0750,
                :owner => "$user",
                :group => "$group",
                :desc => "The Puppet log directory."
            }
        )
    else
        self.setdefaults(:puppet,
            :logdir => ["$vardir/log", "The Puppet log directory."]
        )
    end

    self.setdefaults(:puppet,
        :statedir => { :default => "$vardir/state",
            :mode => 01777,
            :desc => "The directory where Puppet state is stored.  Generally,
                this directory can be removed without causing harm (although it
                might result in spurious service restarts)."
        },
        :rundir => { :default => "$vardir/run",
            :mode => 01777,
            :desc => "Where Puppet PID files are kept."
        },
        :lockdir => { :default => "$vardir/locks",
            :mode => 01777,
            :desc => "Where lock files are kept."
        },
        :statefile => { :default => "$statedir/state.yaml",
            :mode => 0660,
            :desc => "Where puppetd and puppetmasterd store state associated
                with the running configuration.  In the case of puppetmasterd,
                this file reflects the state discovered through interacting
                with clients."
            },
        :ssldir => {
            :default => "$confdir/ssl",
            :mode => 0771,
            :owner => "root",
            :desc => "Where SSL certificates are kept."
        },
        :genconfig => [false,
            "Whether to just print a configuration to stdout and exit.  Only makes
            sense when used interactively.  Takes into account arguments specified
            on the CLI."],
        :genmanifest => [false,
            "Whether to just print a manifest to stdout and exit.  Only makes
            sense when used interactively.  Takes into account arguments specified
            on the CLI."],
        :color => [true, "Whether to use ANSI colors when logging to the console."],
        :mkusers => [false,
            "Whether to create the necessary user and group that puppetd will
            run as."]
    )

    # Define the config default.
    self.setdefaults(self.name,
        :config => ["$confdir/#{self.name}.conf",
            "The configuration file for #{self.name}."]
    )

    self.setdefaults("puppetmasterd",
        :user => ["puppet", "The user puppetmasterd should run as."],
        :group => ["puppet", "The group puppetmasterd should run as."],
        :manifestdir => ["$confdir/manifests",
            "Where puppetmasterd looks for its manifests."],
        :manifest => ["$manifestdir/site.pp",
            "The entry-point manifest for puppetmasterd."],
        :masterlog => { :default => "$logdir/puppetmaster.log",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :desc => "Where puppetmasterd logs.  This is generally not used,
                since syslog is the default log destination."
        },
        :masterhttplog => { :default => "$logdir/masterhttp.log",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :create => true,
            :desc => "Where the puppetmasterd web server logs."
        },
        :masterport => [8140, "Which port puppetmasterd listens on."],
        :parseonly => [false, "Just check the syntax of the manifests."]
    )

    self.setdefaults("puppetd",
        :localconfig => { :default => "$confdir/localconfig",
            :owner => "root",
            :mode => 0660,
            :desc => "Where puppetd caches the local configuration.  An
                extension indicating the cache format is added automatically."},
        :classfile => { :default => "$confdir/classes.txt",
            :owner => "root",
            :mode => 0644,
            :desc => "The file in which puppetd stores a list of the classes
                associated with the retrieved configuratiion.  Can be loaded in
                the separate ``puppet`` executable using the ``--loadclasses``
                option."},
        :puppetdlog => { :default => "$logdir/puppetd.log",
            :owner => "root",
            :mode => 0640,
            :desc => "The log file for puppetd.  This is generally not used."
        },
        :httplog => { :default => "$logdir/http.log",
            :owner => "root",
            :mode => 0640,
            :desc => "Where the puppetd web server logs."
        },
        :server => ["puppet",
            "The server to which server puppetd should connect"],
        :ignoreschedules => [false,
            "Boolean; whether puppetd should ignore schedules.  This is useful
            for initial puppetd runs."],
        :puppetport => [8139, "Which port puppetd listens on."],
        :noop => [false, "Whether puppetd should be run in noop mode."],
        :runinterval => [1800, # 30 minutes
            "How often puppetd applies the client configuration; in seconds"]
    )
    self.setdefaults("metrics",
        :rrddir => ["$vardir/rrd",
            "The directory where RRD database files are stored."],
        :rrdgraph => [false, "Whether RRD information should be graphed."]
    )

	# configuration parameter access and stuff
	def self.[](param)
        case param
        when :debug:
            if Puppet::Log.level == :debug
                return true
            else
                return false
            end
        else
            return @@config[param]
        end
	end

	# configuration parameter access and stuff
	def self.[]=(param,value)
        @@config[param] = value
	end

    def self.clear
        @@config.clear
    end

    def self.debug=(value)
        if value
            Puppet::Log.level=(:debug)
        else
            Puppet::Log.level=(:notice)
        end
    end

    def self.config
        @@config
    end

    def self.genconfig
        if Puppet[:genconfig]
            puts Puppet.config.to_config
            exit(0)
        end
    end

    def self.genmanifest
        if Puppet[:genmanifest]
            puts Puppet.config.to_manifest
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
        @timers ||= []
        timer = EventLoop::Timer.new(hash)
        @timers << timer

        if block_given?
            observe_signal(timer, :alarm, &block)
        end

        # In case they need it for something else.
        timer
    end

    # Trap a couple of the main signals.  This should probably be handled
    # in a way that anyone else can register callbacks for traps, but, eh.
    def self.settraps
        [:INT, :TERM].each do |signal|
            trap(signal) do
                Puppet.notice "Caught #{signal}; shutting down"
                Puppet.shutdown
            end
        end
    end

    # Shutdown our server process, meaning stop all services and all threads.
    # Optionally, exit.
    def self.shutdown(leave = true)
        # Unmonitor our timers
        defined? @timers and @timers.each do |timer|
            EventLoop.current.ignore_timer timer
        end

        if EventLoop.current.running?
            EventLoop.current.quit
        end

        # Stop our services
        defined? @services and @services.each do |svc|
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
        #Puppet.info "Starting loop"
        # Starting everything in its own thread, fwiw
        defined? @timers and @timers.each do |timer|
            EventLoop.current.monitor_timer timer
        end

        defined? @services and @services.each do |svc|
            newthread do
                begin
                    svc.start
                rescue => detail
                    if Puppet[:debug]
                        puts detail.backtrace
                    end
                    Puppet.err "Could not start %s: %s" % [svc.class, detail]
                end
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
    def self.newtype(name, parent = nil, &block)
        Puppet::Type.newtype(name, parent, &block)
    end

    # Retrieve a type by name.  Just proxy to the Type class.
    def self.type(name)
        Puppet::Type.type(name)
    end
end

require 'puppet/server'
require 'puppet/type'
require 'puppet/storage'

# $Id$
