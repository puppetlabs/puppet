# frozen_string_literal: true

require_relative '../../../puppet/file_serving/metadata'
require_relative '../../../puppet/indirector/file_metadata'
require_relative '../../../puppet/indirector/rest'

class Puppet::Indirector::FileMetadata::Rest < Puppet::Indirector::REST
  desc "Retrieve file metadata via a REST HTTP interface."

  def find(request)
    url = URI.parse(Puppet::Util.uri_encode(request.uri))
    session = Puppet.lookup(:http_session)
    api = session.route_to(:fileserver, url: url)

    _, file_metadata = api.get_file_metadata(
      path: Puppet::Util.uri_unescape(url.path),
      environment: request.environment.to_s,
      links: request.options[:links],
      checksum_type: request.options[:checksum_type],
      source_permissions: request.options[:source_permissions]
    )
    file_metadata
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

  def search(request)
    url = URI.parse(Puppet::Util.uri_encode(request.uri))
    session = Puppet.lookup(:http_session)
    api = session.route_to(:fileserver, url: url)

    _, file_metadatas = api.get_file_metadatas(
      path: Puppet::Util.uri_unescape(url.path),
      environment: request.environment.to_s,
      recurse: request.options[:recurse],
      recurselimit: request.options[:recurselimit],
      max_files: request.options[:max_files],
      ignore: request.options[:ignore],
      links: request.options[:links],
      checksum_type: request.options[:checksum_type],
      source_permissions: request.options[:source_permissions]
    )
    file_metadatas
  rescue Puppet::HTTP::ResponseError => e
    # since it's search, return empty array instead of nil
    return [] if e.response.code == 404

    raise convert_to_http_error(e.response)
  end
end
