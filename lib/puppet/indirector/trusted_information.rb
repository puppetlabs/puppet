class Puppet::Indirector::TrustedInformation
  # one of 'remote', 'local', or false, where 'remote' is authenticated via cert,
  # 'local' is trusted by virtue of running on the same machine (not a remove
  # request), and false is an unauthenticated remote request.
  #
  # @return [String, Boolean]
  attr_reader :authenticated

  # The validated certificate name used for the request
  #
  # @return [String]
  attr_reader :certname

  def initialize(authenticated, certname)
    @authenticated = authenticated.freeze
    @certname = certname.freeze
  end

  def self.remote(authenticated, node_name)
    if authenticated
      new('remote', node_name)
    else
      new(false, nil)
    end
  end

  def self.local(node)
    # Always trust local data by picking up the available parameters.
    client_cert = node ? node.parameters['clientcert'] : nil

    new('local', client_cert)
  end

  def to_h
    {
      'authenticated'.freeze => authenticated,
      'certname'.freeze => certname
    }.freeze
  end
end
