require 'puppet'
require 'puppet/daemon'
require 'puppet/application'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/queue'

Puppet::Application.new(:puppetqd) do
    should_parse_config

    attr_accessor :daemon

    preinit do
        @daemon = Puppet::Daemon.new
        @daemon.argv = ARGV.dup

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
    end

    option("--debug","-d")
    option("--verbose","-v")

    command(:main) do
        Puppet::Resource::Catalog::Queue.subscribe do |catalog|
            # Once you have a Puppet::Resource::Catalog instance, calling save() on it should suffice
            # to put it through to the database via its active_record indirector (which is determined
            # by the terminus_class = :active_record setting above)
            Puppet.notice "Processing queued catalog for %s" % catalog.name
            catalog.save
        end

        sleep_forever()
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
    end

    setup do
        unless Puppet.features.stomp?
            raise ArgumentError, "Could not load the 'stomp' library, which must be present for queueing to work.  You must install the required library."
        end

        setup_logs

        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        Puppet::Resource::Catalog.terminus_class = :active_record

        daemon.daemonize if Puppet[:daemonize]
    end

    def sleep_forever
        while true do sleep 1000 end
    end
end
