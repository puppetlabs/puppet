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
    # This works because puppet agent configures Facts to use 'facter' for
    # finding facts and the 'rest' terminus for caching them.  Thus, we'll
    # compile them and then "cache" them on the server.
    begin
      facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value])
      unless Puppet[:node_name_fact].empty?
        Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
        facts.name = Puppet[:node_name_value]
      end
      facts
    rescue SystemExit,NoMemoryError
      raise
    rescue Exception => detail
      puts detail.backtrace if Puppet[:trace]
      raise Puppet::Error, "Could not retrieve local facts: #{detail}"
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

    {:facts_format => format, :facts => CGI.escape(text)}
  end

  # Retrieve facts from the central server.
  def download_fact_plugins
    return unless download_fact_plugins?

    # Deprecated prior to 0.25, as of 5/19/2008
    Puppet.warning "Fact syncing is deprecated as of 0.25 -- use 'pluginsync' instead"

    Puppet::Configurer::Downloader.new("fact", Puppet[:factdest], Puppet[:factsource], Puppet[:factsignore]).evaluate
  end
end
