require 'puppet/indirector/rest'
require 'semantic_puppet'

class Puppet::Transaction::Report::Rest < Puppet::Indirector::REST
  desc "Get server report over HTTP via REST."
  use_server_setting(:report_server)
  use_port_setting(:report_port)
  use_srv_service(:report)

  def handle_response(request, response)
    if !response.is_a?(Net::HTTPSuccess)
      server_version = response[Puppet::Network::HTTP::HEADER_PUPPET_VERSION]
      if server_version &&
         SemanticPuppet::Version.parse(server_version).major < Puppet::Indirector::REST::MAJOR_VERSION_JSON_DEFAULT &&
         Puppet[:preferred_serialization_format] != 'pson'
        format = Puppet[:preferred_serialization_format]
        raise Puppet::Error.new(_("Server version %{version} does not accept reports in '%{format}', use `preferred_serialization_format=pson`") % {version: server_version, format: format})
      end
    end
  end

  private

  def deserialize_save(content_type, body)
    format = Puppet::Network::FormatHandler.format_for(content_type)
    format.intern(Array, body)
  end
end
