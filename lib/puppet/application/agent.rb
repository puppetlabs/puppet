require 'puppet'
require 'puppet/application'
require 'puppet/agent'
require 'puppet/daemon'
require 'puppet/configurer'
require 'puppet/network/client'

class Puppet::Application::Agent < Puppet::Application

    should_parse_config

    attr_accessor :explicit_waitforcert, :args, :agent, :daemon, :host

    def preinit
        # Do an initial trap, so that cancels don't get a stack trace.
        trap(:INT) do
            $stderr.puts "Cancelling startup"
            exit(0)
        end

        {
            :waitforcert => 120,  # Default to checking for certs every 5 minutes
            :onetime => false,
            :detailed_exitcodes => false,
            :verbose => false,
            :debug => false,
            :centrallogs => false,
            :setdest => false,
            :enable => false,
            :disable => false,
            :client => true,
            :fqdn => nil,
            :serve => [],
            :digest => :MD5,
            :fingerprint => false,
        }.each do |opt,val|
            options[opt] = val
        end

        @explicit_waitforcert = false
        @args = {}
        @daemon = Puppet::Daemon.new
        @daemon.argv = ARGV.dup
    end

    option("--centrallogging")
    option("--disable")
    option("--enable")
    option("--debug","-d")
    option("--fqdn FQDN","-f")
    option("--test","-t")
    option("--verbose","-v")

    option("--fingerprint")
    option("--digest DIGEST")

    option("--serve HANDLER", "-s") do |arg|
        if Puppet::Network::Handler.handler(arg)
            options[:serve] << arg.to_sym
        else
            raise "Could not find handler for %s" % arg
        end
    end

    option("--no-client") do |arg|
        options[:client] = false
    end

    option("--onetime", "-o") do |arg|
        options[:onetime] = true
        options[:waitforcert] = 0 unless @explicit_waitforcert
    end

    option("--detailed-exitcodes") do |arg|
        options[:detailed_exitcodes] = true
    end

    option("--logdest DEST", "-l DEST") do |arg|
        begin
            Puppet::Util::Log.newdestination(arg)
            options[:setdest] = true
        rescue => detail
            if Puppet[:debug]
                puts detail.backtrace
            end
            $stderr.puts detail.to_s
        end
    end

    option("--waitforcert WAITFORCERT", "-w") do |arg|
        options[:waitforcert] = arg.to_i
        @explicit_waitforcert = true
    end

    option("--port PORT","-p") do |arg|
        @args[:Port] = arg
    end

    def run_command
        return fingerprint if options[:fingerprint]
        return onetime if options[:onetime]
        return main
    end

    def fingerprint
        unless cert = host.certificate || host.certificate_request
           $stderr.puts "Fingerprint asked but no certificate nor certificate request have yet been issued"
           exit(1)
           return
        end
        unless fingerprint = cert.fingerprint(options[:digest])
            raise ArgumentError, "Could not get fingerprint for digest '#{options[:digest]}'"
        end
        Puppet.notice fingerprint
    end

    def onetime
        unless options[:client]
            $stderr.puts "onetime is specified but there is no client"
            exit(43)
            return
        end

        @daemon.set_signal_traps

        begin
            report = @agent.run
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.err detail.to_s
        end

        if not report
            exit(1)
        elsif not Puppet[:noop] and options[:detailed_exitcodes] then
            exit(report.exit_status)
        else
            exit(0)
        end
    end

    def main
        Puppet.notice "Starting Puppet client version %s" % [Puppet.version]

        @daemon.start
    end

    # Enable all of the most common test options.
    def setup_test
        Puppet.settings.handlearg("--ignorecache")
        Puppet.settings.handlearg("--no-usecacheonfailure")
        Puppet.settings.handlearg("--no-splay")
        Puppet.settings.handlearg("--show_diff")
        Puppet.settings.handlearg("--no-daemonize")
        options[:verbose] = true
        options[:onetime] = true
        options[:detailed_exitcodes] = true
        options[:waitforcert] = 0 unless @explicit_waitforcert
    end

    # Handle the logging settings.
    def setup_logs
        if options[:debug] or options[:verbose]
            Puppet::Util::Log.newdestination(:console)
            if options[:debug]
                Puppet::Util::Log.level = :debug
            else
                Puppet::Util::Log.level = :info
            end
        end

        unless options[:setdest]
            Puppet::Util::Log.newdestination(:syslog)
        end
    end

    def enable_disable_client(agent)
        if options[:enable]
            agent.enable
        elsif options[:disable]
            agent.disable
        end
        exit(0)
    end

    def setup_listen
        unless FileTest.exists?(Puppet[:authconfig])
            Puppet.err "Will not start without authorization file %s" %
                Puppet[:authconfig]
            exit(14)
        end

        handlers = nil

        if options[:serve].empty?
            handlers = [:Runner]
        else
            handlers = options[:serve]
        end

        require 'puppet/network/server'
        # No REST handlers yet.
        server = Puppet::Network::Server.new(:xmlrpc_handlers => handlers, :port => Puppet[:puppetport])

        @daemon.server = server
    end

    def setup
        setup_test if options[:test]

        setup_logs

        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        # If noop is set, then also enable diffs
        if Puppet[:noop]
            Puppet[:show_diff] = true
        end

        args[:Server] = Puppet[:server]
        if options[:fqdn]
            args[:FQDN] = options[:fqdn]
            Puppet[:certname] = options[:fqdn]
        end

        if options[:centrallogs]
            logdest = args[:Server]

            if args.include?(:Port)
                logdest += ":" + args[:Port]
            end
            Puppet::Util::Log.newdestination(logdest)
        end

        Puppet.settings.use :main, :puppetd, :ssl

        # We need to specify a ca location for all of the SSL-related i
        # indirected classes to work; in fingerprint mode we just need 
        # access to the local files and we don't need a ca.
        Puppet::SSL::Host.ca_location = options[:fingerprint] ? :none : :remote

        Puppet::Transaction::Report.terminus_class = :rest

        # Override the default; puppetd needs this, usually.
        # You can still override this on the command-line with, e.g., :compiler.
        Puppet[:catalog_terminus] = :rest

        Puppet::Resource::Catalog.cache_class = :yaml

        Puppet::Node::Facts.terminus_class = :facter

        # We need tomake the client either way, we just don't start it
        # if --no-client is set.
        @agent = Puppet::Agent.new(Puppet::Configurer)

        enable_disable_client(@agent) if options[:enable] or options[:disable]

        @daemon.agent = agent if options[:client]

        # It'd be nice to daemonize later, but we have to daemonize before the
        # waitforcert happens.
        if Puppet[:daemonize]
            @daemon.daemonize
        end

        @host = Puppet::SSL::Host.new
        unless options[:fingerprint]
            cert = @host.wait_for_cert(options[:waitforcert])
        end

        @objects = []

        # This has to go after the certs are dealt with.
        if Puppet[:listen]
            unless options[:onetime]
                setup_listen
            else
                Puppet.notice "Ignoring --listen on onetime run"
            end
        end
    end
end
