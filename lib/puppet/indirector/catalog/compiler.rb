require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/code'
require 'yaml'

class Puppet::Resource::Catalog::Compiler < Puppet::Indirector::Code
  desc "Puppet's catalog compilation interface, and its back-end is
    Puppet's compiler"

  include Puppet::Util

  attr_accessor :code

  def extract_facts_from_request(request)
    return unless text_facts = request.options[:facts]
    raise ArgumentError, "Facts but no fact format provided for #{request.name}" unless format = request.options[:facts_format]

    # If the facts were encoded as yaml, then the param reconstitution system
    # in Network::HTTP::Handler will automagically deserialize the value.
    if text_facts.is_a?(Puppet::Node::Facts)
      facts = text_facts
    else
      facts = Puppet::Node::Facts.convert_from(format, text_facts)
    end
    facts.add_timestamp
    Puppet::Node::Facts.indirection.save(facts)
  end

  # Compile a node's catalog.
  def find(request)
    extract_facts_from_request(request)

    node = node_from_request(request)

    if catalog = compile(node)
      return catalog
    else
      # This shouldn't actually happen; we should either return
      # a config or raise an exception.
      return nil
    end
  end

  # filter-out a catalog to remove exported resources
  def filter(catalog)
    return catalog.filter { |r| r.virtual? } if catalog.respond_to?(:filter)
    catalog
  end

  def initialize
    set_server_facts
    setup_database_backend if Puppet[:storeconfigs]
  end

  # Is our compiler part of a network, or are we just local?
  def networked?
    Puppet.run_mode.master?
  end

  private

  # Add any extra data necessary to the node.
  def add_node_data(node)
    # Merge in our server-side facts, so they can be used during compilation.
    node.merge(@server_facts)
  end

  # Compile the actual catalog.
  def compile(node)
    str = "Compiled catalog for #{node.name}"
    str += " in environment #{node.environment}" if node.environment
    config = nil

    loglevel = networked? ? :notice : :none

    benchmark(loglevel, str) do
      begin
        config = Puppet::Parser::Compiler.compile(node)
      rescue Puppet::Error => detail
        Puppet.err(detail.to_s) if networked?
        raise
      end
    end

    config
  end

  # Turn our host name into a node object.
  def find_node(name)
    begin
      return nil unless node = Puppet::Node.indirection.find(name)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise Puppet::Error, "Failed when searching for node #{name}: #{detail}"
    end


    # Add any external data to the node.
    add_node_data(node)

    node
  end

  # Extract the node from the request, or use the request
  # to find the node.
  def node_from_request(request)
    if node = request.options[:use_node]
      return node
    end

    # We rely on our authorization system to determine whether the connected
    # node is allowed to compile the catalog's node referenced by key.
    # By default the REST authorization system makes sure only the connected node
    # can compile his catalog.
    # This allows for instance monitoring systems or puppet-load to check several
    # node's catalog with only one certificate and a modification to auth.conf 
    # If no key is provided we can only compile the currently connected node.
    name = request.key || request.node
    if node = find_node(name)
      return node
    end

    raise ArgumentError, "Could not find node '#{name}'; cannot compile"
  end

  # Initialize our server fact hash; we add these to each client, and they
  # won't change while we're running, so it's safe to cache the values.
  def set_server_facts
    @server_facts = {}

    # Add our server version to the fact list
    @server_facts["serverversion"] = Puppet.version.to_s

    # And then add the server name and IP
    {"servername" => "fqdn",
      "serverip" => "ipaddress"
    }.each do |var, fact|
      if value = Facter.value(fact)
        @server_facts[var] = value
      else
        Puppet.warning "Could not retrieve fact #{fact}"
      end
    end

    if @server_facts["servername"].nil?
      host = Facter.value(:hostname)
      if domain = Facter.value(:domain)
        @server_facts["servername"] = [host, domain].join(".")
      else
        @server_facts["servername"] = host
      end
    end
  end

  def setup_database_backend
    raise Puppet::Error, "Rails is missing; cannot store configurations" unless Puppet.features.rails?
    Puppet::Rails.init
  end

  # Mark that the node has checked in. LAK:FIXME this needs to be moved into
  # the Node class, or somewhere that's got abstract backends.
  def update_node_check(node)
    if Puppet.features.rails? and Puppet[:storeconfigs]
      Puppet::Rails.connect

      host = Puppet::Rails::Host.find_or_create_by_name(node.name)
      host.last_freshcheck = Time.now
      host.save
    end
  end
end
