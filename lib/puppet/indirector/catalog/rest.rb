require 'puppet/resource/catalog'
require 'puppet/indirector/rest'

class Puppet::Resource::Catalog::Rest < Puppet::Indirector::REST
  desc "Find resource catalogs over HTTP via REST."

  def find(request)
    return super unless use_http_client?

    checksum_type = if request.options[:checksum_type]
                      request.options[:checksum_type].split('.')
                    else
                      Puppet[:supported_checksum_types]
                    end

    session = Puppet.lookup(:http_session)
    api = session.route_to(:puppet)
    api.get_catalog(
      request.key,
      facts: request.options[:facts_for_catalog],
      environment: request.environment.to_s,
      configured_environment: request.options[:configured_environment],
      transaction_uuid: request.options[:transaction_uuid],
      job_uuid: request.options[:job_id],
      static_catalog: request.options[:static_catalog],
      checksum_type: checksum_type
    )
  rescue Puppet::HTTP::ResponseError => e
    if e.response.code == 404
      return nil unless request.options[:fail_on_404]

      _, body = parse_response(e.response.nethttp)
      msg = _("Find %{uri} resulted in 404 with the message: %{body}") % { uri: elide(e.response.url.path, 100), body: body }
      raise Puppet::Error, msg
    else
      raise convert_to_http_error(e.response.nethttp)
    end
  end
end
