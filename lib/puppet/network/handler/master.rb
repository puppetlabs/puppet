require 'openssl'
require 'puppet'
require 'xmlrpc/server'
require 'yaml'
require 'puppet/network/handler'

class Puppet::Network::Handler
  class MasterError < Puppet::Error; end
  class Master < Handler
    desc "Puppet's configuration interface.  Used for all interactions related to
    generating client configurations."

    include Puppet::Util

    attr_accessor :ast
    attr_reader :ca

    @interface = XMLRPC::Service::Interface.new("puppetmaster") { |iface|
        iface.add_method("string getconfig(string)")
        iface.add_method("int freshness()")
    }

    # Tell a client whether there's a fresh config for it
    def freshness(client = nil, clientip = nil)
      # Always force a recompile.  Newer clients shouldn't do this (as of April 2008).
      Time.now.to_i
    end

    def initialize(hash = {})
      args = {}

      @local = hash[:Local]

      args[:Local] = true

      # This is only used by the cfengine module, or if --loadclasses was
      # specified in +puppet+.
      args[:Classes] = hash[:Classes] if hash.include?(:Classes)
    end

    # Call our various handlers; this handler is getting deprecated.
    def getconfig(facts, format = "marshal", client = nil, clientip = nil)
      facts = decode_facts(facts)

      client ||= facts["hostname"]

      # Pass the facts to the fact handler
      Puppet::Node::Facts.indirection.save(Puppet::Node::Facts.new(client, facts)) unless local?

      catalog = Puppet::Resource::Catalog.indirection.find(client)

      case format
      when "yaml"
        return CGI.escape(catalog.extract.to_yaml)
      when "marshal"
        return CGI.escape(Marshal.dump(catalog.extract))
      else
        raise "Invalid markup format '#{format}'"
      end
    end

    #
    def decode_facts(facts)
      if @local
        # we don't need to do anything, since we should already
        # have raw objects
        Puppet.debug "Our client is local"
      else
        Puppet.debug "Our client is remote"

        begin
          facts = YAML.load(CGI.unescape(facts))
        rescue => detail
          raise XMLRPC::FaultException.new(
            1, "Could not rebuild facts"
          )
        end
      end

      facts
    end

    # Translate our configuration appropriately for sending back to a client.
    def translate(config)
    end
  end
end
