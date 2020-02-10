require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/rest'

class Puppet::Indirector::FileContent::Rest < Puppet::Indirector::REST
  desc "Retrieve file contents via a REST HTTP interface."

  use_srv_service(:fileserver)

  def find(request)
    return super unless use_http_client?

    content = StringIO.new
    content.binmode

    url = URI.parse(Puppet::Util.uri_encode(request.uri))
    session = Puppet.lookup(:http_session)
    api = session.route_to(:fileserver, url: url)

    api.get_file_content(
      path: URI.unescape(url.path),
      environment: request.environment.to_s,
    ) do |data|
      content << data
    end

    Puppet::FileServing::Content.from_binary(content.string)
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
