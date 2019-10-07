module Puppet
  module Acceptance
    module AgentFqdnUtils

      @@hostname_to_fqdn = {}

      # convert from an Beaker::Host (agent) to the systems fqdn as returned by facter
      def agent_to_fqdn(agent)
        unless @@hostname_to_fqdn.has_key?(agent.hostname)
          @@hostname_to_fqdn[agent.hostname] = on(agent, facter('fqdn')).stdout.chomp
        end
        @@hostname_to_fqdn[agent.hostname]
      end
    end
  end
end
