require 'puppet'
require 'puppet/application'
require 'puppet/daemon'
require 'puppet/network/server'

Puppet::Application.new(:puppetmasterd) do

    should_parse_config

    option("--debug", "-d")
    option("--verbose", "-v")

    option("--logdest",  "-l") do |arg|
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

    preinit do
        trap(:INT) do
            $stderr.puts "Cancelling startup"
            exit(0)
        end

        # Create this first-off, so we have ARGV
        @daemon = Puppet::Daemon.new
        @daemon.argv = ARGV.dup
    end

    dispatch do
        return Puppet[:parseonly] ? :parseonly : :main
    end

    command(:parseonly) do
        begin
            Puppet::Parser::Interpreter.new.parser(Puppet[:environment])
        rescue => detail
            Puppet.err detail
            exit 1
        end
        exit(0)
    end

    command(:main) do
        require 'etc'
        require 'puppet/file_serving/content'
        require 'puppet/file_serving/metadata'
        require 'puppet/checksum'

        xmlrpc_handlers = [:Status, :FileServer, :Master, :Report, :Filebucket]

        if Puppet[:ca]
            xmlrpc_handlers << :CA
        end

        @daemon.server = Puppet::Network::Server.new(:xmlrpc_handlers => xmlrpc_handlers)

        # Make sure we've got a localhost ssl cert
        Puppet::SSL::Host.localhost

        # And now configure our server to *only* hit the CA for data, because that's
        # all it will have write access to.
        if Puppet::SSL::CertificateAuthority.ca?
            Puppet::SSL::Host.ca_location = :only
        end

        if Process.uid == 0
            begin
                Puppet::Util.chuser
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                $stderr.puts "Could not change user to %s: %s" % [Puppet[:user], detail]
                exit(39)
            end
        end

        @daemon.daemonize if Puppet[:daemonize]

        Puppet.notice "Starting Puppet server version %s" % [Puppet.version]

        @daemon.start
    end

    setup do
        # Handle the logging settings.
        if options[:debug] or options[:verbose]
            if options[:debug]
                Puppet::Util::Log.level = :debug
            else
                Puppet::Util::Log.level = :info
            end

            unless Puppet[:daemonize]
                Puppet::Util::Log.newdestination(:console)
                options[:setdest] = true
            end
        end

        unless options[:setdest]
            Puppet::Util::Log.newdestination(:syslog)
        end

        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        Puppet.settings.use :main, :puppetmasterd, :ssl

        # A temporary solution, to at least make the master work for now.
        Puppet::Node::Facts.terminus_class = :yaml

        # Cache our nodes in yaml.  Currently not configurable.
        Puppet::Node.cache_class = :yaml

        # Configure all of the SSL stuff.
        if Puppet::SSL::CertificateAuthority.ca?
            Puppet::SSL::Host.ca_location = :local
            Puppet.settings.use :ca
            Puppet::SSL::CertificateAuthority.instance
        else
            Puppet::SSL::Host.ca_location = :none
        end
    end
end
