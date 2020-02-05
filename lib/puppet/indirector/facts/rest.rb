require 'puppet/node/facts'
require 'puppet/indirector/rest'

class Puppet::Node::Facts::Rest < Puppet::Indirector::REST
  desc "Find and save facts about nodes over HTTP via REST."

  def save(request)
    raise ArgumentError, _("PUT does not accept options") unless request.options.empty?

    return legacy_save(request) unless use_http_client?

    session = Puppet.lookup(:http_session)
    api = session.route_to(:puppet)
    api.put_facts(
      request.key,
      facts: request.instance,
      environment: request.environment.to_s
    )

    # preserve existing behavior
    nil
  rescue Puppet::HTTP::ResponseError => e
    # always raise even if fail_on_404 is false
    raise convert_to_http_error(e.response.nethttp)
  end

  private

  def legacy_save(request)
    response = do_request(request) do |req|
      http_put(req, IndirectedRoutes.request_to_uri(req), req.instance.render, headers.merge({ "Content-Type" => req.instance.mime }))
    end

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_save(content_type, body)
    else
      raise convert_to_http_error(response)
    end
  end
end
