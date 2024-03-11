# frozen_string_literal: true

require_relative '../../../puppet/resource/catalog'
require_relative '../../../puppet/indirector/rest'

class Puppet::Resource::Catalog::Rest < Puppet::Indirector::REST
  desc "Find resource catalogs over HTTP via REST."

  def find(request)
    checksum_type = if request.options[:checksum_type]
                      request.options[:checksum_type].split('.')
                    else
                      Puppet[:supported_checksum_types]
                    end

    session = Puppet.lookup(:http_session)
    api = session.route_to(:puppet)

    unless Puppet.settings[:skip_logging_catalog_request_destination]
      ip_address = begin
        " (#{Resolv.getaddress(api.url.host)})"
      rescue Resolv::ResolvError
        nil
      end
      Puppet.notice("Requesting catalog from #{api.url.host}:#{api.url.port}#{ip_address}")
    end

    _, catalog = api.post_catalog(
      request.key,
      facts: request.options[:facts_for_catalog],
      environment: request.environment.to_s,
      configured_environment: request.options[:configured_environment],
      check_environment: request.options[:check_environment],
      transaction_uuid: request.options[:transaction_uuid],
      job_uuid: request.options[:job_id],
      static_catalog: request.options[:static_catalog],
      checksum_type: checksum_type
    )
    catalog
  rescue Puppet::HTTP::ResponseError => e
    if e.response.code == 404
      return nil unless request.options[:fail_on_404]

      _, body = parse_response(e.response)
      msg = _("Find %{uri} resulted in 404 with the message: %{body}") % { uri: elide(e.response.url.path, 100), body: body }
      raise Puppet::Error, msg
    else
      raise convert_to_http_error(e.response)
    end
  end
end
