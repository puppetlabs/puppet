require 'puppet/indirector'

# A class for managing nodes, including their facts and environment.
class Puppet::Node
  require 'puppet/node/facts'
  require 'puppet/node/inventory'
  require 'puppet/node/environment'

  # Set up indirection, so that nodes can be looked for in
  # the node sources.
  extend Puppet::Indirector

  # Adds the environment getter and setter, with some instance/string conversion
  include Puppet::Node::Environment::Helper

  # Use the node source as the indirection terminus.
  indirects :node, :terminus_setting => :node_terminus, :doc => "Where to find node information.
    A node is composed of its name, its facts, and its environment."

  attr_accessor :name, :classes, :source, :ipaddress, :parameters
  attr_reader :time

  def environment
    return super if @environment

    if env = parameters["environment"]
      self.environment = env
      return super
    end

    # Else, return the default
    Puppet::Node::Environment.new
  end

  def initialize(name, options = {})
    raise ArgumentError, "Node names cannot be nil" unless name
    @name = name

    if classes = options[:classes]
      if classes.is_a?(String)
        @classes = [classes]
      else
        @classes = classes
      end
    else
      @classes = []
    end

    @parameters = options[:parameters] || {}

    if env = options[:environment]
      self.environment = env
    end

    @time = Time.now
  end

  # Merge the node facts with parameters from the node source.
  def fact_merge
      if facts = Puppet::Node::Facts.indirection.find(name)
        merge(facts.values)
      end
  rescue => detail
      error = Puppet::Error.new("Could not retrieve facts for #{name}: #{detail}")
      error.set_backtrace(detail.backtrace)
      raise error
  end

  # Merge any random parameters into our parameter list.
  def merge(params)
    params.each do |name, value|
      @parameters[name] = value unless @parameters.include?(name)
    end

    @parameters["environment"] ||= self.environment.name.to_s if self.environment
  end

  # Calculate the list of names we might use for looking
  # up our node.  This is only used for AST nodes.
  def names
    return [name] if Puppet.settings[:strict_hostname_checking]

    names = []

    names += split_name(name) if name.include?(".")

    # First, get the fqdn
    unless fqdn = parameters["fqdn"]
      if parameters["hostname"] and parameters["domain"]
        fqdn = parameters["hostname"] + "." + parameters["domain"]
      else
        Puppet.warning "Host is missing hostname and/or domain: #{name}"
      end
    end

    # Now that we (might) have the fqdn, add each piece to the name
    # list to search, in order of longest to shortest.
    names += split_name(fqdn) if fqdn

    # And make sure the node name is first, since that's the most
    # likely usage.
    #   The name is usually the Certificate CN, but it can be
    # set to the 'facter' hostname instead.
    if Puppet[:node_name] == 'cert'
      names.unshift name
    else
      names.unshift parameters["hostname"]
    end
    names.uniq
  end

  def split_name(name)
    list = name.split(".")
    tmp = []
    list.each_with_index do |short, i|
      tmp << list[0..i].join(".")
    end
    tmp.reverse
  end
end
