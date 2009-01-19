require 'puppet/agent'

# The class that handles sleeping for the appropriate splay
# time, if at all.
class Puppet::Agent::Splayer
    attr_reader :splayed

    # Should we splay?
    def splay?
        Puppet[:splay]
    end

    # Sleep for a random but consistent period of time if configured to
    # do so.
    def splay
        return unless Puppet[:splay]
        return if splayed?

        time = rand(Integer(Puppet[:splaylimit]) + 1)
        Puppet.info "Sleeping for %s seconds (splay is enabled)" % time
        sleep(time)
        @splayed = true
    end

    # Have we already splayed?
    def splayed?
        defined?(@splayed) and @splayed
    end
end
