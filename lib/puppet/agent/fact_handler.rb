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

    def load_fact_plugins
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = Puppet[:factpath].split(":").each do |dir|
            load_facts_in_dir(dir)
        end
    end

    def load_facts_in_dir(dir)
        return unless FileTest.directory?(dir)

        Dir.chdir(dir) do
            Dir.glob("*.rb").each do |file|
                fqfile = ::File.join(dir, file)
                begin
                    Puppet.info "Loading facts in %s" % [::File.basename(file.sub(".rb",''))]
                    Timeout::timeout(Puppet::Agent.timeout) do
                        load file
                    end
                rescue => detail
                    Puppet.warning "Could not load fact file %s: %s" % [fqfile, detail]
                end
            end
        end
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
        load_fact_plugins()
    end
end
