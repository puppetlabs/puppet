require 'puppet'
require 'puppet/daemon'
require 'puppet/application'
require 'puppet/node/catalog'
require 'puppet/indirector/catalog/queue'

Puppet::Application.new(:puppetqd) do
    extend Puppet::Daemon

    should_parse_config

    preinit do
        # Do an initial trap, so that cancels don't get a stack trace.
        trap(:INT) do
            $stderr.puts "Cancelling startup"
            exit(0)
        end

        {
            :verbose => false,
            :debug => false
        }.each do |opt,val|
            options[opt] = val
        end

        @args = {}
    end

    option("--debug","-d")
    option("--verbose","-v")

    command(:main) do
        Puppet::Node::Catalog::Queue.subscribe do |catalog|
            # Once you have a Puppet::Node::Catalog instance, calling save() on it should suffice
            # to put it through to the database via its active_record indirector (which is determined
            # by the terminus_class = :active_record setting above)
            Puppet.notice "Processing queued catalog for %s" % catalog.name
            catalog.save
        end
        daemonize if Puppet[:daemonize]

        while true do sleep 1000 end
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

    setup do
        unless Puppet.features.stomp?
            raise ArgumentError, "Could not load 'stomp', which must be present for queueing to work"
        end

        setup_logs

        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        Puppet::Node::Catalog.terminus_class = :active_record
    end
end
