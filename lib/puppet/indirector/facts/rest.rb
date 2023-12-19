# frozen_string_literal: true

require_relative '../../../puppet/node/facts'
require_relative '../../../puppet/indirector/rest'

class Puppet::Node::Facts::Rest < Puppet::Indirector::REST
  desc "Find and save facts about nodes over HTTP via REST."

  def find(request)
    session = Puppet.lookup(:http_session)
    api = session.route_to(:puppet)
    _, facts = api.get_facts(
      request.key,
      environment: request.environment.to_s
    )
    facts
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

  def save(request)
    raise ArgumentError, _("PUT does not accept options") unless request.options.empty?

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
    raise convert_to_http_error(e.response)
  end
end
