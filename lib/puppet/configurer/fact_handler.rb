require 'puppet/indirector/facts/facter'

require 'puppet/configurer'
require 'puppet/configurer/downloader'

# Break out the code related to facts.  This module is
# just included into the agent, but having it here makes it
# easier to test.
module Puppet::Configurer::FactHandler
  def find_facts
    # This works because puppet agent configures Facts to use 'facter' for
    # finding facts and the 'rest' terminus for caching them.  Thus, we'll
    # compile them and then "cache" them on the server.
    begin
      facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value], :environment => @environment)
      unless Puppet[:node_name_fact].empty?
        Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
        facts.name = Puppet[:node_name_value]
      end
      facts
    rescue SystemExit,NoMemoryError
      raise
    rescue Exception => detail
      message = "Could not retrieve local facts: #{detail}"
      Puppet.log_exception(detail, message)
      raise Puppet::Error, message
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
end
