require 'puppet'
require 'puppet/application'
require 'puppet/daemon'
require 'puppet/network/server'
require 'puppet/network/http/rack' if Puppet.features.rack?

class Puppet::Application::Master < Puppet::Application

    should_parse_config

    option("--debug", "-d")
    option("--verbose", "-v")

    # internal option, only to be used by ext/rack/config.ru
    option("--rack")

    option("--compile host",  "-c host") do |arg|
        options[:node] = arg
    end

    option("--logdest DEST",  "-l DEST") do |arg|
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

    def preinit
        trap(:INT) do
            $stderr.puts "Cancelling startup"
            exit(0)
        end

        # Create this first-off, so we have ARGV
        @daemon = Puppet::Daemon.new
        @daemon.argv = ARGV.dup
    end

    def run_command
        if options[:node]
            compile
        elsif Puppet[:parseonly]
            parseonly
        else
            main
        end
    end

    def compile
        Puppet::Util::Log.newdestination :console
        raise ArgumentError, "Cannot render compiled catalogs without pson support" unless Puppet.features.pson?
        begin
            unless catalog = Puppet::Resource::Catalog.find(options[:node])
                raise "Could not compile catalog for %s" % options[:node] 
            end

            $stdout.puts catalog.render(:pson)
        rescue => detail
            $stderr.puts detail
            exit(30)
        end
        exit(0)
    end

    def parseonly
        begin
            Puppet::Resource::TypeCollection.new(Puppet[:environment]).perform_initial_import
        rescue => detail
            Puppet.err detail
            exit 1
        end
        exit(0)
    end

    def main
        require 'etc'
        require 'puppet/file_serving/content'
        require 'puppet/file_serving/metadata'

        xmlrpc_handlers = [:Status, :FileServer, :Master, :Report, :Filebucket]

        if Puppet[:ca]
            xmlrpc_handlers << :CA
        end

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

        unless options[:rack]
            @daemon.server = Puppet::Network::Server.new(:xmlrpc_handlers => xmlrpc_handlers)
            @daemon.daemonize if Puppet[:daemonize]
        else
            require 'puppet/network/http/rack'
            @app = Puppet::Network::HTTP::Rack.new(:xmlrpc_handlers => xmlrpc_handlers, :protocols => [:rest, :xmlrpc])
        end

        Puppet.notice "Starting Puppet master version %s" % [Puppet.version]

        unless options[:rack]
            @daemon.start
        else
            return @app
        end
    end

    def setup
        # Handle the logging settings.
        if options[:debug] or options[:verbose]
            if options[:debug]
                Puppet::Util::Log.level = :debug
            else
                Puppet::Util::Log.level = :info
            end

            unless Puppet[:daemonize] or options[:rack]
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
