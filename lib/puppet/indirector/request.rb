require 'cgi'
require 'uri'
require 'puppet/indirector'
require 'puppet/util/pson'
require 'puppet/network/resolver'

# This class encapsulates all of the information you need to make an
# Indirection call, and as a result also handles REST calls.  It's somewhat
# analogous to an HTTP Request object, except tuned for our Indirector.
class Puppet::Indirector::Request
  attr_accessor :key, :method, :options, :instance, :node, :ip, :authenticated, :ignore_cache, :ignore_terminus

  attr_accessor :server, :port, :uri, :protocol

  attr_reader :indirection_name

  # trusted_information is specifically left out because we can't serialize it
  # and keep it "trusted"
  OPTION_ATTRIBUTES = [:ip, :node, :authenticated, :ignore_terminus, :ignore_cache, :instance, :environment]

  ::PSON.register_document_type('IndirectorRequest',self)

  def self.from_data_hash(data)
    raise ArgumentError, "No indirection name provided in data" unless indirection_name = data['type']
    raise ArgumentError, "No method name provided in data" unless method = data['method']
    raise ArgumentError, "No key provided in data" unless key = data['key']

    request = new(indirection_name, method, key, nil, data['attributes'])

    if instance = data['instance']
      klass = Puppet::Indirector::Indirection.instance(request.indirection_name).model
      if instance.is_a?(klass)
        request.instance = instance
      else
        request.instance = klass.from_data_hash(instance)
      end
    end

    request
  end

  def self.from_pson(json)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(json)
  end

  def to_data_hash
    result = {
      'type' => indirection_name,
      'method' => method,
      'key' => key
    }
    attributes = {}
    OPTION_ATTRIBUTES.each do |key|
      next unless value = send(key)
      attributes[key] = value
    end

    options.each do |opt, value|
      attributes[opt] = value
    end

    result['attributes'] = attributes unless attributes.empty?
    result['instance'] = instance if instance
    result
  end

  def to_pson_data_hash
    {
      'document_type' => 'IndirectorRequest',
      'data' => to_data_hash,
    }
  end

  def to_pson(*args)
    to_pson_data_hash.to_pson(*args)
  end

  # Is this an authenticated request?
  def authenticated?
    # Double negative, so we just get true or false
    ! ! authenticated
  end

  def environment
    # If environment has not been set directly, we should use the application's
    # current environment
    @environment ||= Puppet.lookup(:current_environment)
  end

  def environment=(env)
    @environment =
    if env.is_a?(Puppet::Node::Environment)
      env
    elsif (current_environment = Puppet.lookup(:current_environment)).name == env
      current_environment
    else
      Puppet.lookup(:environments).get!(env)
    end
  end

  def escaped_key
    URI.escape(key)
  end

  # LAK:NOTE This is a messy interface to the cache, and it's only
  # used by the Configurer class.  I decided it was better to implement
  # it now and refactor later, when we have a better design, than
  # to spend another month coming up with a design now that might
  # not be any better.
  def ignore_cache?
    ignore_cache
  end

  def ignore_terminus?
    ignore_terminus
  end

  def initialize(indirection_name, method, key, instance, options = {})
    @instance = instance
    options ||= {}

    self.indirection_name = indirection_name
    self.method = method

    options = options.inject({}) { |hash, ary| hash[ary[0].to_sym] = ary[1]; hash }

    set_attributes(options)

    @options = options

    if key
      # If the request key is a URI, then we need to treat it specially,
      # because it rewrites the key.  We could otherwise strip server/port/etc
      # info out in the REST class, but it seemed bad design for the REST
      # class to rewrite the key.

      if key.to_s =~ /^\w+:\// and not Puppet::Util.absolute_path?(key.to_s) # it's a URI
        set_uri_key(key)
      else
        @key = key
      end
    end

    @key = @instance.name if ! @key and @instance
  end

  # Look up the indirection based on the name provided.
  def indirection
    Puppet::Indirector::Indirection.instance(indirection_name)
  end

  def indirection_name=(name)
    @indirection_name = name.to_sym
  end

  def model
    raise ArgumentError, "Could not find indirection '#{indirection_name}'" unless i = indirection
    i.model
  end

  # Are we trying to interact with multiple resources, or just one?
  def plural?
    method == :search
  end

  # Create the query string, if options are present.
  def query_string
    return "" if options.nil? || options.empty?

    # For backward compatibility with older (pre-3.3) masters,
    # this puppet option allows serialization of query parameter
    # arrays as yaml.  This can be removed when we remove yaml
    # support entirely.
    if Puppet.settings[:legacy_query_parameter_serialization]
      replace_arrays_with_yaml
    end

    "?" + encode_params(expand_into_parameters(options.to_a))
  end

  def replace_arrays_with_yaml
    options.each do |key, value|
      case value
        when Array
          options[key] = YAML.dump(value)
      end
    end
  end

  def expand_into_parameters(data)
    data.inject([]) do |params, key_value|
      key, value = key_value

      expanded_value = case value
                       when Array
                         value.collect { |val| [key, val] }
                       else
                         [key_value]
                       end

      params.concat(expand_primitive_types_into_parameters(expanded_value))
    end
  end

  def expand_primitive_types_into_parameters(data)
    data.inject([]) do |params, key_value|
      key, value = key_value
      case value
      when nil
        params
      when true, false, String, Symbol, Fixnum, Bignum, Float
        params << [key, value]
      else
        raise ArgumentError, "HTTP REST queries cannot handle values of type '#{value.class}'"
      end
    end
  end

  def encode_params(params)
    params.collect do |key, value|
      "#{key}=#{CGI.escape(value.to_s)}"
    end.join("&")
  end

  def to_hash
    result = options.dup

    OPTION_ATTRIBUTES.each do |attribute|
      if value = send(attribute)
        result[attribute] = value
      end
    end
    result
  end

  def to_s
    return(uri ? uri : "/#{indirection_name}/#{key}")
  end

  def do_request(srv_service=:puppet, default_server=Puppet.settings[:server], default_port=Puppet.settings[:masterport], &block)
    # We were given a specific server to use, so just use that one.
    # This happens if someone does something like specifying a file
    # source using a puppet:// URI with a specific server.
    return yield(self) if !self.server.nil?

    if Puppet.settings[:use_srv_records]
      Puppet::Network::Resolver.each_srv_record(Puppet.settings[:srv_domain], srv_service) do |srv_server, srv_port|
        begin
          self.server = srv_server
          self.port   = srv_port
          return yield(self)
        rescue SystemCallError => e
          Puppet.warning "Error connecting to #{srv_server}:#{srv_port}: #{e.message}"
        end
      end
    end

    # ... Fall back onto the default server.
    Puppet.debug "No more servers left, falling back to #{default_server}:#{default_port}" if Puppet.settings[:use_srv_records]
    self.server = default_server
    self.port   = default_port
    return yield(self)
  end

  def remote?
    self.node or self.ip
  end

  private

  def set_attributes(options)
    OPTION_ATTRIBUTES.each do |attribute|
      if options.include?(attribute.to_sym)
        send(attribute.to_s + "=", options[attribute])
        options.delete(attribute)
      end
    end
  end

  # Parse the key as a URI, setting attributes appropriately.
  def set_uri_key(key)
    @uri = key
    begin
      uri = URI.parse(URI.escape(key))
    rescue => detail
      raise ArgumentError, "Could not understand URL #{key}: #{detail}", detail.backtrace
    end

    # Just short-circuit these to full paths
    if uri.scheme == "file"
      @key = Puppet::Util.uri_to_path(uri)
      return
    end

    @server = uri.host if uri.host

    # If the URI class can look up the scheme, it will provide a port,
    # otherwise it will default to '0'.
    if uri.port.to_i == 0 and uri.scheme == "puppet"
      @port = Puppet.settings[:masterport].to_i
    else
      @port = uri.port.to_i
    end

    @protocol = uri.scheme

    if uri.scheme == 'puppet'
      @key = URI.unescape(uri.path.sub(/^\//, ''))
      return
    end

    env, indirector, @key = URI.unescape(uri.path.sub(/^\//, '')).split('/',3)
    @key ||= ''
    self.environment = env unless env == ''
  end
end
