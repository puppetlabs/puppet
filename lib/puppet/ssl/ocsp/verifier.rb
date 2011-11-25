require 'puppet/ssl/ocsp'
require 'puppet/ssl/ocsp/response'
require 'puppet/ssl/ocsp/request'

module Puppet::SSL::Ocsp::Verifier
  module_function

  def verify(to_check, ssl_host)
    request = Puppet::SSL::Ocsp::Request.new("n/a").generate(to_check, ssl_host.certificate, ssl_host.key, Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME))
    response = Puppet::SSL::Ocsp::Request.indirection.save(request)
    response = response.is_a?(String) ? Puppet::SSL::Ocsp::Response.from_yaml(response) : Puppet::SSL::Ocsp::Response.new("n/a").content = response
    response.verify(request)
  end
end
