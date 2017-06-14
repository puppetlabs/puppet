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
      facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value], :environment => Puppet::Node::Environment.remote(@environment))
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
      raise Puppet::Error, message, detail.backtrace
    end
  end

  def facts_for_uploading
    facts = find_facts

    text = facts.render(:pson)

    {:facts_format => :pson, :facts => CGI.escape(text)}
  end
end
