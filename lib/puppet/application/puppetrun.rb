require 'puppet'
require 'puppet/application'

Puppet.warning "RubyGems not installed" unless Puppet.features.rubygems?
Puppet.warning "Failed to load ruby LDAP library. LDAP functionality will not be available" unless Puppet.features.ldap?

Puppet::Application.new(:puppetrun) do

    should_not_parse_config

    attr_accessor :hosts, :tags, :classes

    option("--all","-a")
    option("--foreground","-f")
    option("--debug","-d")
    option("--ping","-P")
    option("--test")

    option("--host HOST") do |arg|
        @hosts << arg
    end

    option("--tag TAG", "-t") do |arg|
        @tags << arg
    end

    option("--class CLASS", "-c") do |arg|
        @classes << arg
    end

    option("--no-fqdn", "-n") do |arg|
        options[:fqdn] = false
    end

    option("--parallel PARALLEL", "-p") do |arg|
        begin
            options[:parallel] = Integer(arg)
        rescue
            $stderr.puts "Could not convert %s to an integer" % arg.inspect
            exit(23)
        end
    end


    dispatch do
        options[:test] ? :test : :main
    end

    command(:test) do
        puts "Skipping execution in test mode"
        exit(0)
    end

    command(:main) do
        require 'puppet/network/client'
        require 'puppet/util/ldap/connection'

        todo = @hosts.dup

        failures = []

        # Now do the actual work
        go = true
        while go
            # If we don't have enough children in process and we still have hosts left to
            # do, then do the next host.
            if @children.length < options[:parallel] and ! todo.empty?
                host = todo.shift
                pid = fork do
                    run_for_host(host)
                end
                @children[pid] = host
            else
                # Else, see if we can reap a process.
                begin
                    pid = Process.wait

                    if host = @children[pid]
                        # Remove our host from the list of children, so the parallelization
                        # continues working.
                        @children.delete(pid)
                        if $?.exitstatus != 0
                            failures << host
                        end
                        print "%s finished with exit code %s\n" % [host, $?.exitstatus]
                    else
                        $stderr.puts "Could not find host for PID %s with status %s" %
                            [pid, $?.exitstatus]
                    end
                rescue Errno::ECHILD
                    # There are no children left, so just exit unless there are still
                    # children left to do.
                    next unless todo.empty?

                    if failures.empty?
                        puts "Finished"
                        exit(0)
                    else
                        puts "Failed: %s" % failures.join(", ")
                        exit(3)
                    end
                end
            end
        end
    end

    def run_for_host(host)
        if options[:ping]
            out = %x{ping -c 1 #{host}}
            unless $? == 0
                $stderr.print "Could not contact %s\n" % host
                next
            end
        end
        client = Puppet::Network::Client.runner.new(
            :Server => host,
            :Port => Puppet[:puppetport]
        )

        print "Triggering %s\n" % host
        begin
            result = client.run(@tags, options[:ignoreschedules] || false, options[:foreground] || false)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            $stderr.puts "Host %s failed: %s\n" % [host, detail]
            exit(2)
        end

        case result
        when "success"; exit(0)
        when "running"
            $stderr.puts "Host %s is already running" % host
            exit(3)
        else
            $stderr.puts "Host %s returned unknown answer '%s'" % [host, result]
            exit(12)
        end
    end

    preinit do
        [:INT, :TERM].each do |signal|
            trap(signal) do
                $stderr.puts "Cancelling"
                exit(1)
            end
        end
        options[:parallel] = 1
        options[:verbose] = true
        options[:fqdn] = true
        options[:ignoreschedules] = false
        options[:foreground] = false

        @hosts = []
        @classes = []
        @tags = []
    end

    setup do
        if options[:debug]
            Puppet::Util::Log.level = :debug
        else
            Puppet::Util::Log.level = :info
        end

        # Now parse the config
        Puppet.parse_config

        if Puppet[:node_terminus] == "ldap" and (options[:all] or @classes)
            if options[:all]
                @hosts = Puppet::Node.search("whatever", :fqdn => options[:fqdn]).collect { |node| node.name }
                puts "all: %s" % @hosts.join(", ")
            else
                @hosts = []
                @classes.each do |klass|
                    list = Puppet::Node.search("whatever", :fqdn => options[:fqdn], :class => klass).collect { |node| node.name }
                    puts "%s: %s" % [klass, list.join(", ")]

                    @hosts += list
                end
            end
        elsif ! @classes.empty?
            $stderr.puts "You must be using LDAP to specify host classes"
            exit(24)
        end

        if @tags.empty?
            @tags = ""
        else
            @tags = @tags.join(",")
        end

        @children = {}

        # If we get a signal, then kill all of our children and get out.
        [:INT, :TERM].each do |signal|
            trap(signal) do
                Puppet.notice "Caught #{signal}; shutting down"
                @children.each do |pid, host|
                    Process.kill("INT", pid)
                end

                waitall

                exit(1)
            end
        end

    end

end
