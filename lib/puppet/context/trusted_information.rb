# frozen_string_literal: true

require_relative '../../puppet/trusted_external'

# @api private
class Puppet::Context::TrustedInformation
  # one of 'remote', 'local', or false, where 'remote' is authenticated via cert,
  # 'local' is trusted by virtue of running on the same machine (not a remote
  # request), and false is an unauthenticated remote request.
  #
  # @return [String, Boolean]
  attr_reader :authenticated

  # The validated certificate name used for the request
  #
  # @return [String]
  attr_reader :certname

  # Extra information that comes from the trusted certificate's extensions.
  #
  # @return [Hash{Object => Object}]
  attr_reader :extensions

  # The domain name derived from the validated certificate name
  #
  # @return [String]
  attr_reader :domain

  # The hostname derived from the validated certificate name
  #
  # @return [String]
  attr_reader :hostname

  def initialize(authenticated, certname, extensions, external = {})
    @authenticated = authenticated.freeze
    @certname = certname.freeze
    @extensions = extensions.freeze
    if @certname
      hostname, domain = @certname.split('.', 2)
    else
      hostname = nil
      domain = nil
    end
    @hostname = hostname.freeze
    @domain = domain.freeze
    @external = external.is_a?(Proc) ? external : external.freeze
  end

  def self.remote(authenticated, node_name, certificate)
    external = proc { retrieve_trusted_external(node_name) }

    if authenticated
      extensions = {}
      if certificate.nil?
        Puppet.info(_('TrustedInformation expected a certificate, but none was given.'))
      else
        extensions = certificate.custom_extensions.to_h do |ext|
          [ext['oid'].freeze, ext['value'].freeze]
        end
      end
      new('remote', node_name, extensions, external)
    else
      new(false, nil, {}, external)
    end
  end

  def self.local(node)
    # Always trust local data by picking up the available parameters.
    client_cert = node ? node.parameters['clientcert'] : nil
    external = proc { retrieve_trusted_external(client_cert) }

    new('local', client_cert, {}, external)
  end

  # Additional external facts loaded through `trusted_external_command`.
  #
  # @return [Hash]
  def external
    if @external.is_a?(Proc)
      @external = @external.call.freeze
    end
    @external
  end

  def self.retrieve_trusted_external(certname)
    deep_freeze(Puppet::TrustedExternal.retrieve(certname) || {})
  end
  private_class_method :retrieve_trusted_external

  # Deeply freezes the given object. The object and its content must be of the types:
  # Array, Hash, Numeric, Boolean, Regexp, NilClass, or String. All other types raises an Error.
  # (i.e. if they are assignable to Puppet::Pops::Types::Data type).
  def self.deep_freeze(object)
    case object
    when Array
      object.each { |v| deep_freeze(v) }
      object.freeze
    when Hash
      object.each { |k, v| deep_freeze(k); deep_freeze(v) }
      object.freeze
    when NilClass, Numeric, TrueClass, FalseClass
      # do nothing
    when String
      object.freeze
    else
      raise Puppet::Error, _("Unsupported data type: '%{klass}'") % { klass: object.class }
    end
    object
  end
  private_class_method :deep_freeze

  def to_h
    {
      'authenticated' => authenticated,
      'certname' => certname,
      'extensions' => extensions,
      'hostname' => hostname,
      'domain' => domain,
      'external' => external,
    }.freeze
  end
end
