require 'puppet/indirector/facts/facter'

require 'puppet/configurer/downloader'

# Break out the code related to facts.  This module is
# just included into the agent, but having it here makes it
# easier to test.
module Puppet::Configurer::FactHandler
    def download_fact_plugins?
        Puppet[:factsync]
    end

    def find_facts
        # This works because puppetd configures Facts to use 'facter' for
        # finding facts and the 'rest' terminus for caching them.  Thus, we'll
        # compile them and then "cache" them on the server.
        begin
            reload_facter()
            Puppet::Node::Facts.find(Puppet[:certname])
        rescue SystemExit,NoMemoryError
            raise
        rescue Exception => detail
            puts detail.backtrace if Puppet[:trace]
            raise Puppet::Error, "Could not retrieve local facts: %s" % detail
        end
    end

    def facts_for_uploading
        facts = find_facts
        #format = facts.class.default_format

        if facts.support_format?(:b64_zlib_yaml)
            format = :b64_zlib_yaml
        else
            format = :yaml
        end

        text = facts.render(format)

        return {:facts_format => format, :facts => CGI.escape(text)}
    end

    # Retrieve facts from the central server.
    def download_fact_plugins
        return unless download_fact_plugins?

        # Deprecated prior to 0.25, as of 5/19/2008
        Puppet.warning "Fact syncing is deprecated as of 0.25 -- use 'pluginsync' instead"

        Puppet::Configurer::Downloader.new("fact", Puppet[:factdest], Puppet[:factsource], Puppet[:factsignore]).evaluate
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
