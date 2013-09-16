require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/rest'

class Puppet::Indirector::FileMetadata::Rest < Puppet::Indirector::REST
  desc "Retrieve file metadata via a REST HTTP interface."

  use_srv_service(:fileserver)

  def http_get (request, path, headers = nil, *args)
    response = super

    if !request.supports_protocol_version?(response["X-Puppet-Protocol-Version"])
      Puppet.warning "Server does not support the agent protocol version - file resource ignore lists won't work."
      Puppet.warning "You can fix this either by upgrading the puppet master (recommended), or setting"
      Puppet.warning "legacy_query_parameter_serialization=true on the agent."

      raise Puppet::Error, "Server does not support agent protocol version"
    end

    response
  end
end
