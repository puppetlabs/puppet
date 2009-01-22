require 'puppet/indirector/facts/facter'

# Break out the code related to facts.  This module is
# just included into the agent, but having it here makes it
# easier to test.
module Puppet::Agent::FactHandler
    def download_fact_plugins?
        Puppet[:factsync]
    end

    def upload_facts
        # XXX down = Puppet[:downcasefacts]

        reload_facter()

        # This works because puppetd configures Facts to use 'facter' for
        # finding facts and the 'rest' terminus for caching them.  Thus, we'll
        # compile them and then "cache" them on the server.
        Puppet::Node::Facts.find(Puppet[:certname])
    end

    # Retrieve facts from the central server.
    def download_fact_plugins
        return unless download_fact_plugins?

        Puppet::Agent::Downloader.new("fact", Puppet[:factsource], Puppet[:factdest], Puppet[:factsignore]).evaluate
    end

    # Clear out all of the loaded facts and reload them from disk.
    # NOTE: This is clumsy and shouldn't be required for later (1.5.x) versions
    # of Facter.
    def reload_facter
        Facter.clear

        # Reload everything.
        if Facter.respond_to? :loadfacts
            Facter.loadfacts
        elsif Facter.respond_to? :load
            Facter.load
        else
            Puppet.warning "You should upgrade your version of Facter to at least 1.3.8"
        end

        # This loads all existing facts and any new ones.  We have to remove and
        # reload because there's no way to unload specific facts.
        Puppet::Node::Facts::Facter.load_fact_plugins()
    end
end
