require 'puppet/file_serving/http_metadata'
require 'puppet/indirector/generic_http'
require 'puppet/indirector/file_metadata'
require 'net/http'

class Puppet::Indirector::FileMetadata::Http < Puppet::Indirector::GenericHttp
  desc "Retrieve file metadata from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  def find(request)
    uri = URI(request.uri)
    client = Puppet.runtime[:http]
    head = client.head(uri, headers: {'Connection' => 'close'}, options: {include_system_store: true})

    if head.success?
      metadata = Puppet::FileServing::HttpMetadata.new(head)
      metadata.checksum_type = request.options[:checksum_type] if request.options[:checksum_type]
      metadata.collect
      metadata
    end
  end

  def search(request)
    raise Puppet::Error, _("cannot lookup multiple files")
  end
end
