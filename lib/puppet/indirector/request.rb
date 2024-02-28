# frozen_string_literal: true

require 'cgi'
require 'uri'
require_relative '../../puppet/indirector'
require_relative '../../puppet/util/psych_support'
require_relative '../../puppet/util/warnings'

# This class encapsulates all of the information you need to make an
# Indirection call, and as a result also handles REST calls.  It's somewhat
# analogous to an HTTP Request object, except tuned for our Indirector.
class Puppet::Indirector::Request
  include Puppet::Util::PsychSupport
  include Puppet::Util::Warnings

  attr_accessor :key, :method, :options, :instance, :node, :ip, :authenticated, :ignore_cache, :ignore_cache_save, :ignore_terminus

  attr_accessor :server, :port, :uri, :protocol

  attr_reader :indirection_name

  # trusted_information is specifically left out because we can't serialize it
  # and keep it "trusted"
  OPTION_ATTRIBUTES = [:ip, :node, :authenticated, :ignore_terminus, :ignore_cache, :ignore_cache_save, :instance, :environment]

  # Is this an authenticated request?
  def authenticated?
    # Double negative, so we just get true or false
    !!authenticated
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

  # LAK:NOTE This is a messy interface to the cache, and it's only
  # used by the Configurer class.  I decided it was better to implement
  # it now and refactor later, when we have a better design, than
  # to spend another month coming up with a design now that might
  # not be any better.
  def ignore_cache?
    ignore_cache
  end

  def ignore_cache_save?
    ignore_cache_save
  end

  def ignore_terminus?
    ignore_terminus
  end

  def initialize(indirection_name, method, key, instance, options = {})
    @instance = instance
    options ||= {}

    self.indirection_name = indirection_name
    self.method = method

    options = options.each_with_object({}) { |ary, hash| hash[ary[0].to_sym] = ary[1]; }

    set_attributes(options)

    @options = options

    if key
      # If the request key is a URI, then we need to treat it specially,
      # because it rewrites the key.  We could otherwise strip server/port/etc
      # info out in the REST class, but it seemed bad design for the REST
      # class to rewrite the key.

      if key.to_s =~ /^\w+:\// and !Puppet::Util.absolute_path?(key.to_s) # it's a URI
        set_uri_key(key)
      else
        @key = key
      end
    end

    @key = @instance.name if !@key and @instance
  end

  # Look up the indirection based on the name provided.
  def indirection
    Puppet::Indirector::Indirection.instance(indirection_name)
  end

  def indirection_name=(name)
    @indirection_name = name.to_sym
  end

  def model
    ind = indirection
    raise ArgumentError, _("Could not find indirection '%{indirection}'") % { indirection: indirection_name } unless ind

    ind.model
  end

  # Are we trying to interact with multiple resources, or just one?
  def plural?
    method == :search
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
      value = send(attribute)
      if value
        result[attribute] = value
      end
    end
    result
  end

  def description
    return(uri ? uri : "/#{indirection_name}/#{key}")
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
      # calling uri_encode for UTF-8 characters will % escape them and keep them UTF-8
      uri = URI.parse(Puppet::Util.uri_encode(key))
    rescue => detail
      raise ArgumentError, _("Could not understand URL %{key}: %{detail}") % { key: key, detail: detail }, detail.backtrace
    end

    # Just short-circuit these to full paths
    if uri.scheme == "file"
      @key = Puppet::Util.uri_to_path(uri)
      return
    end

    @server = uri.host if uri.host && !uri.host.empty?

    # If the URI class can look up the scheme, it will provide a port,
    # otherwise it will default to '0'.
    if uri.port.to_i == 0 and uri.scheme == "puppet"
      @port = Puppet.settings[:serverport].to_i
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

    @key = Puppet::Util.uri_unescape(uri.path.sub(/^\//, ''))
  end
end
