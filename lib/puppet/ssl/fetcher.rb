require 'puppet/ssl'

class Puppet::SSL::Fetcher
  CA_NAME = 'ca'

  def initialize(ssl_context)
    @ssl_context = ssl_context
  end

  def fetch_cacerts
    Puppet::Rest::Routes.get_certificate(CA_NAME, @ssl_context)
  rescue Puppet::Rest::ResponseError => e
    if e.response.code.to_i == 404
      raise Puppet::Error.new(_('CA certificate is missing from the server'))
    else
      raise Puppet::Error.new(_('Could not download CA certificate: %{message}') % { message: e.message }, e)
    end
  end

  def fetch_crls
    Puppet::Rest::Routes.get_crls(CA_NAME, @ssl_context)
  rescue Puppet::Rest::ResponseError => e
    if e.response.code.to_i == 404
      raise Puppet::Error.new(_('CRL is missing from the server'))
    else
      raise Puppet::Error.new(_('Could not download CRLs: %{message}') % { message: e.message }, e)
    end
  end
end
