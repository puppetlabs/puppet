require 'puppet/agent'
require 'puppet/configurer'
require 'puppet/indirector'

# A basic class for running the agent.  Used by
# puppetrun to kick off agents remotely.
class Puppet::Agent::Runner
    extend Puppet::Indirector
    indirects :runner, :terminus_class => :rest

    attr_reader :status, :background, :options

    def agent
        Puppet::Agent.new(Puppet::Configurer)
    end

    def background?
        background
    end

    def initialize(options = {})
        if options.include?(:background)
            @background = options[:background]
            options.delete(:background)
        end

        valid_options = [:tags, :ignoreschedules]
        options.each do |key, value|
            raise ArgumentError, "Runner does not accept %s" % key unless valid_options.include?(key)
        end

        @options = options
    end

    def log_run
        msg = ""
        msg += "triggered run" %
        if options[:tags]
            msg += " with tags %s" % options[:tags]
        end

        if options[:ignoreschedules]
            msg += " ignoring schedules"
        end

        Puppet.notice msg
    end

    def run
        if agent.running?
            @status = "running"
            return
        end

        log_run()

        if background?
            Thread.new { agent.run(options) }
        else
            agent.run(options)
        end

        @status = "success"
    end
end
