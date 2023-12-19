# frozen_string_literal: true

require_relative '../../../puppet/indirector/rest'
require 'semantic_puppet'

class Puppet::Transaction::Report::Rest < Puppet::Indirector::REST
  desc "Get server report over HTTP via REST."

  def save(request)
    session = Puppet.lookup(:http_session)
    api = session.route_to(:report)
    response = api.put_report(
      request.key,
      request.instance,
      environment: request.environment.to_s
    )
    content_type, body = parse_response(response)
    deserialize_save(content_type, body)
  rescue Puppet::HTTP::ResponseError => e
    return nil if e.response.code == 404

    raise convert_to_http_error(e.response)
  end

  private

  def deserialize_save(content_type, body)
    format = Puppet::Network::FormatHandler.format_for(content_type)
    format.intern(Array, body)
  end
end
