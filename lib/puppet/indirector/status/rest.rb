require 'puppet/indirector/status'
require 'puppet/indirector/rest'

class Puppet::Indirector::Status::Rest < Puppet::Indirector::REST

  desc "Get puppet master's status via REST. Useful because it tests the health
    of both the web server and the indirector."

  def find(request)
    return super unless use_http_client?

    session = Puppet.lookup(:http_session)
    api = session.route_to(:puppet)
    _, status = api.get_status(request.key)
    status
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
