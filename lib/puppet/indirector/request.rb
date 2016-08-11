require 'cgi'
require 'uri'
require 'puppet/indirector'
require 'puppet/network/resolver'
require 'puppet/util/psych_support'

# This class encapsulates all of the information you need to make an
# Indirection call, and as a result also handles REST calls.  It's somewhat
# analogous to an HTTP Request object, except tuned for our Indirector.
class Puppet::Indirector::Request
  include Puppet::Util::PsychSupport

  attr_accessor :key, :method, :options, :instance, :node, :ip, :authenticated, :ignore_cache, :ignore_terminus

  attr_accessor :server, :port, :uri, :protocol

  attr_reader :indirection_name

  # trusted_information is specifically left out because we can't serialize it
  # and keep it "trusted"
  OPTION_ATTRIBUTES = [:ip, :node, :authenticated, :ignore_terminus, :ignore_cache, :instance, :environment]

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
    encode_params(expand_into_parameters(options.to_a))
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

  def initialize_from_hash(hash)
    @indirection_name = hash['indirection_name'].to_sym
    @method = hash['method'].to_sym
    @key = hash['key']
    @instance = hash['instance']
    @options = hash['options']
  end

  def to_data_hash
    { 'indirection_name' => @indirection_name.to_s,
      'method' => @method.to_s,
      'key' => @key,
      'instance' => @instance,
      'options' => @options }
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

  def description
    return(uri ? uri : "/#{indirection_name}/#{key}")
  end

  def do_request(srv_service=:puppet, default_server=nil, default_port=nil, &block)
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
    begin
      bound_server = Puppet.lookup(:server)
    rescue
      if primary_server = Puppet.settings[:server_list][0]
        bound_server = primary_server[0]
      else
        bound_server = nil
      end
    end

    begin
      bound_port = Puppet.lookup(:serverport)
    rescue
      if primary_server = Puppet.settings[:server_list][0]
        bound_port = primary_server[1]
      else
        bound_port = nil
      end
    end
    self.server = default_server || bound_server || Puppet.settings[:server]
    self.port   = default_port || bound_port || Puppet.settings[:masterport]

    Puppet.debug "No more servers left, falling back to #{self.server}:#{self.port}" if Puppet.settings[:use_srv_records]

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

    # filebucket:// is only used internally to pass request details
    # from Dipper objects to the indirector. The wire always uses HTTPS.
    if uri.scheme == 'filebucket'
      @protocol = 'https'
    else
      @protocol = uri.scheme
    end

    @key = URI.unescape(uri.path.sub(/^\//, ''))
  end
end
