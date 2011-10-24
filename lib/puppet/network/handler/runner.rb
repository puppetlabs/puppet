require 'puppet/run'
require 'puppet/network/handler'
require 'xmlrpc/server'

class Puppet::Network::Handler
  class MissingMasterError < RuntimeError; end # Cannot find the master client
  # A simple server for triggering a new run on a Puppet client.
  class Runner < Handler
    desc "An interface for triggering client configuration runs."

    @interface = XMLRPC::Service::Interface.new("puppetrunner") { |iface|
      iface.add_method("string run(string, string)")
    }

    side :client

    # Run the client configuration right now, optionally specifying
    # tags and whether to ignore schedules
    def run(tags = nil, ignoreschedules = false, fg = true, client = nil, clientip = nil)
      options = {}
      options[:tags] = tags if tags
      options[:ignoreschedules] = ignoreschedules if ignoreschedules
      options[:background] = !fg

      runner = Puppet::Run.new(options)

      runner.run

      runner.status
    end
  end
end

