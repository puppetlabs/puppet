require 'puppet/resource/catalog'
require 'puppet/indirector/rest'

class Puppet::Resource::Catalog::Rest < Puppet::Indirector::REST
  desc "Find resource catalogs over HTTP via REST."

  def find(request)
    return super unless use_http_client?

    # URL encoded facts and facts_format are passed as indirector
    # request options, so we have to reverse that (unescape, then parse),
    # and pass a facts object to the http client.
    format = request.options[:facts_format]
    if format
      formatter = Puppet::Network::FormatHandler.format_for(format)
      facts = formatter.intern(Puppet::Node::Facts, CGI.unescape(request.options[:facts]))
    else
      facts = Puppet::Node::Facts.new(request.key, environment: request.environment.to_s)
    end

    checksum_type = if request.options[:checksum_type]
                      request.options[:checksum_type].split('.')
                    else
                      Puppet[:supported_checksum_types]
                    end

    session = Puppet.lookup(:http_session)
    api = session.route_to(:puppet)
    catalog = api.post_catalog(
      request.key,
      facts: facts,
      environment: request.environment.to_s,
      configured_environment: request.options[:configured_environment],
      transaction_uuid: request.options[:transaction_uuid],
      job_uuid: request.options[:job_id],
      static_catalog: request.options[:static_catalog],
      checksum_type: checksum_type
    )
    # current tests rely on crazy behavior introduced in 089ac3e37dd
    catalog.name = request.key
    catalog
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
