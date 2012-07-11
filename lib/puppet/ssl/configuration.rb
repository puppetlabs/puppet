require 'puppet/ssl'
module Puppet
module SSL
  # Puppet::SSL::Configuration is intended to separate out the following concerns:
  # * CA certificates that authenticate peers (ca_auth_file)
  # * CA certificates that build trust but do not authenticate (ca_chain_file)
  # * Who clients trust as distinct from who servers trust.  We should not
  #   assume one single self signed CA cert for everyone.
class Configuration
  def initialize(localcacert, options={})
    if (options[:ca_chain_file] and not options[:ca_auth_file])
      raise ArgumentError, "The CA auth chain is required if the chain file is provided"
    end
    @localcacert = localcacert
    @ca_chain_file = options[:ca_chain_file]
    @ca_auth_file = options[:ca_auth_file]
  end

  # The ca_chain_file method is intended to return the PEM bundle of CA certs
  # establishing trust but not used for peer authentication.
  def ca_chain_file
    @ca_chain_file || ca_auth_file
  end

  # The ca_auth_file method is intended to return the PEM bundle of CA certs
  # used to authenticate peer connections.
  def ca_auth_file
    @ca_auth_file || @localcacert
  end
end
end
end
