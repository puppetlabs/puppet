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
    env_name = data['environment'] || @parameters[ENVIRONMENT]
    unless env_name.nil?
      @parameters[ENVIRONMENT] = env_name
      @environment_name = env_name.intern
    end
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
    serialized_params = self.serializable_parameters
    result['parameters'] = serialized_params unless serialized_params.empty?
    result
  end

  def serializable_parameters
    new_params = parameters.dup
    new_params.delete(ENVIRONMENT)
    new_params
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
        # it will be used to establish what the current environment is.
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
      # always set the environment parameter. It becomes top scope $environment for a manifest during catalog compilation.
      @parameters[ENVIRONMENT] = @environment.name.to_s
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
      # facts should never modify the environment parameter
      orig_param_env = @parameters[ENVIRONMENT]
      merge(@facts.values)
      @parameters[ENVIRONMENT] = orig_param_env
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
  end

  # Add extra facts, such as facts given to lookup on the command line The
  # extra facts will override existing ones.
  # @param extra_facts [Hash{String=>Object}] the facts to tadd
  # @api private
  def add_extra_facts(extra_facts)
    @facts.add_extra_values(extra_facts)
    @parameters.merge!(extra_facts)
    nil
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

  # Resurrects and sanitizes trusted information in the node by modifying it and setting
  # the trusted_data in the node from parameters.
  # This modifies the node
  #
  def sanitize
    # Resurrect "trusted information" that comes from node/fact terminus.
    # The current way this is done in puppet db (currently the only one)
    # is to store the node parameter 'trusted' as a hash of the trusted information.
    #
    # Thus here there are two main cases:
    # 1. This terminus was used in a real agent call (only meaningful if someone curls the request as it would
    #  fail since the result is a hash of two catalogs).
    # 2  It is a command line call with a given node that use a terminus that:
    # 2.1 does not include a 'trusted' fact - use local from node trusted information
    # 2.2 has a 'trusted' fact - this in turn could be
    # 2.2.1 puppet db having stored trusted node data as a fact (not a great design)
    # 2.2.2 some other terminus having stored a fact called "trusted" (most likely that would have failed earlier, but could
    #       be spoofed).
    #
    # For the reasons above, the resurrection of trusted node data with authenticated => true is only performed
    # if user is running as root, else it is resurrected as unauthenticated.
    #
    trusted_param = @parameters['trusted']
    if trusted_param
      # Blows up if it is a parameter as it will be set as $trusted by the compiler as if it was a variable
      @parameters.delete('trusted')
      unless trusted_param.is_a?(Hash) && %w{authenticated certname extensions}.all? {|key| trusted_param.has_key?(key) }
        # trusted is some kind of garbage, do not resurrect
        trusted_param = nil
      end
    else
      # trusted may be Boolean false if set as a fact by someone
      trusted_param = nil
    end

    # The options for node.trusted_data in priority order are:
    # 1) node came with trusted_data so use that
    # 2) else if there is :trusted_information in the puppet context
    # 3) else if the node provided a 'trusted' parameter (parsed out above)
    # 4) last, fallback to local node trusted information
    #
    # Note that trusted_data should be a hash, but (2) and (4) are not
    # hashes, so we to_h at the end
    if !trusted_data
      trusted = Puppet.lookup(:trusted_information) do
        trusted_param || Puppet::Context::TrustedInformation.local(self)
      end

      # Ruby 1.9.3 can't apply to_h to a hash, so check first
      self.trusted_data = (trusted.is_a?(Hash) ? trusted : trusted.to_h)
    end
  end
end
