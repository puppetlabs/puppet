require 'puppet/indirector'

# A class for managing nodes, including their facts and environment.
class Puppet::Node
  require 'puppet/node/facts'
  require 'puppet/node/environment'

  # Set up indirection, so that nodes can be looked for in
  # the node sources.
  extend Puppet::Indirector

  # Asymmetric serialization/deserialization required in this class via to/from datahash
  include Puppet::Util::PsychSupport

  # Use the node source as the indirection terminus.
  indirects :node, :terminus_setting => :node_terminus, :doc => "Where to find node information.
    A node is composed of its name, its facts, and its environment."

  attr_accessor :name, :classes, :source, :ipaddress, :parameters, :trusted_data, :environment_name
  attr_reader :time, :facts

  attr_reader :server_facts

  ENVIRONMENT = 'environment'.freeze

  def initialize_from_hash(data)
    @name       = data['name']       || (raise ArgumentError, _("No name provided in serialized data"))
    @classes    = data['classes']    || []
    @parameters = data['parameters'] || {}
    env_name = data['environment']
    env_name = env_name.intern unless env_name.nil?
    @environment_name = env_name
    environment = env_name
  end

  def self.from_data_hash(data)
    node = new(name)
    node.initialize_from_hash(data)
    node
  end

  def to_data_hash
    result = {
      'name' => name,
      'environment' => environment.name.to_s,
    }
    result['classes'] = classes unless classes.empty?
    result['parameters'] = parameters unless parameters.empty?
    result
  end

  def environment
    if @environment
      @environment
    else
      if env = parameters[ENVIRONMENT]
        self.environment = env
      elsif environment_name
        self.environment = environment_name
      else
        # This should not be :current_environment, this is the default
        # for a node when it has not specified its environment
        # Tt will be used to establish what the current environment is.
        #
        self.environment = Puppet.lookup(:environments).get!(Puppet[:environment])
      end

      @environment
    end
  end

  def environment=(env)
    if env.is_a?(String) or env.is_a?(Symbol)
      @environment = Puppet.lookup(:environments).get!(env)
    else
      @environment = env
    end

    # Keep environment_name attribute and parameter in sync if they have been set
    unless @environment.nil?
      @parameters[ENVIRONMENT] = @environment.name.to_s if @parameters.include?(ENVIRONMENT)
      self.environment_name = @environment.name if instance_variable_defined?(:@environment_name)
    end
    @environment
  end

  def has_environment_instance?
    !@environment.nil?
  end

  def initialize(name, options = {})
    raise ArgumentError, _("Node names cannot be nil") unless name
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

    @facts = options[:facts]

    @server_facts = {}

    if env = options[:environment]
      self.environment = env
    end

    @time = Time.now
  end

  # Merge the node facts with parameters from the node source.
  # @api public
  # @param facts [optional, Puppet::Node::Facts] facts to merge into node parameters.
  #   Will query Facts indirection if not supplied.
  # @raise [Puppet::Error] Raise on failure to retrieve facts if not supplied
  # @return [nil]
  def fact_merge(facts = nil)
    begin
      @facts = facts.nil? ? Puppet::Node::Facts.indirection.find(name, :environment => environment) : facts
    rescue => detail
      error = Puppet::Error.new(_("Could not retrieve facts for %{name}: %{detail}") % { name: name, detail: detail }, detail)
      error.set_backtrace(detail.backtrace)
      raise error
    end

    if !@facts.nil?
      @facts.sanitize
      merge(@facts.values)
    end
  end

  # Merge any random parameters into our parameter list.
  def merge(params)
    params.each do |name, value|
      if @parameters.include?(name)
        Puppet::Util::Warnings.warnonce(_("The node parameter '%{param_name}' for node '%{node_name}' was already set to '%{value}'. It could not be set to '%{desired_value}'") % { param_name: name, node_name: @name, value: @parameters[name], desired_value: value })
      else
        @parameters[name] = value
      end
    end

    @parameters[ENVIRONMENT] ||= self.environment.name.to_s
  end

  def add_server_facts(facts)
    # Append the current environment to the list of server facts
    @server_facts = facts.merge({ "environment" => self.environment.name.to_s})

    # Merge the server facts into the parameters for the node
    merge(facts)
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
        Puppet.warning _("Host is missing hostname and/or domain: %{name}") % { name: name }
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

  # Ensures the data is frozen
  #
  def trusted_data=(data)
    Puppet.warning(_("Trusted node data modified for node %{name}") % { name: name }) unless @trusted_data.nil?
    @trusted_data = data.freeze
  end
end
