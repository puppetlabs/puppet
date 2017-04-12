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

  def initialize(authenticated, certname, extensions)
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
  end

  def self.remote(authenticated, node_name, certificate)
    if authenticated
      extensions = {}
      if certificate.nil?
        Puppet.info(_('TrustedInformation expected a certificate, but none was given.'))
      else
        extensions = Hash[certificate.custom_extensions.collect do |ext|
          [ext['oid'].freeze, ext['value'].freeze]
        end]
      end
      new('remote', node_name, extensions)
    else
      new(false, nil, {})
    end
  end

  def self.local(node)
    # Always trust local data by picking up the available parameters.
    client_cert = node ? node.parameters['clientcert'] : nil

    new('local', client_cert, {})
  end

  def to_h
    {
      'authenticated'.freeze => authenticated,
      'certname'.freeze => certname,
      'extensions'.freeze => extensions,
      'hostname'.freeze => hostname,
      'domain'.freeze => domain,
    }.freeze
  end
end
