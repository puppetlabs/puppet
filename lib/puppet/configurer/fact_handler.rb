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
      message = _("Could not retrieve local facts: %{detail}") % { detail: detail }
      Puppet.log_exception(detail, message)
      raise Puppet::Error, message, detail.backtrace
    end
  end

  def facts_for_uploading
    facts = find_facts

    # NOTE: :facts specified as parameters are URI encoded here,
    # then  encoded for a second time depending on their length:
    #
    # <= 1024 characters sent via query string of a HTTP GET, additionally query string encoded
    # > 1024 characters sent in POST data, additionally x-www-form-urlencoded
    # so it's only important that encoding method here return original values
    # correctly when CGI.unescape called against it (in compiler code)
    if Puppet[:preferred_serialization_format] == "pson"
      {:facts_format => :pson, :facts => Puppet::Util.uri_query_encode(facts.render(:pson)) }
    else
      {:facts_format => 'application/json', :facts => Puppet::Util.uri_query_encode(facts.render(:json)) }
    end
  end
end
