require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/rest'

class Puppet::Indirector::FileMetadata::Rest < Puppet::Indirector::REST
  desc "Retrieve file metadata via a REST HTTP interface."

  use_srv_service(:fileserver)

  def find(request)
    return super unless use_http_client?

    url = URI.parse(Puppet::Util.uri_encode(request.uri))
    session = Puppet.lookup(:http_session)
    api = session.route_to(:fileserver, url: url)

    api.get_file_metadata(
      path: url.path,
      environment: request.environment.to_s,
      links: request.options[:links],
      checksum_type: request.options[:checksum_type],
      source_permissions: request.options[:source_permissions]
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

  def search(request)
    return super unless use_http_client?

    url = URI.parse(Puppet::Util.uri_encode(request.uri))
    session = Puppet.lookup(:http_session)
    api = session.route_to(:fileserver, url: url)

    api.get_file_metadatas(
      path: url.path,
      environment: request.environment.to_s,
      recurse: request.options[:recurse],
      recurselimit: request.options[:recurselimit],
      ignore: request.options[:ignore],
      links: request.options[:links],
      checksum_type: request.options[:checksum_type],
      source_permissions: request.options[:source_permissions],
    )
  rescue Puppet::HTTP::ResponseError => e
    return [] if e.response.code == 404

    raise convert_to_http_error(e.response.nethttp)
  end
end
