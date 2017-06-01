require 'puppet/file_serving/http_metadata'
require 'puppet/indirector/generic_http'
require 'puppet/indirector/file_metadata'
require 'net/http'

class Puppet::Indirector::FileMetadata::Http < Puppet::Indirector::GenericHttp
  desc "Retrieve file metadata from a remote HTTP server."

  include Puppet::FileServing::TerminusHelper

  @http_method = :head

  def find(request)
    head = super

    if head.is_a?(Net::HTTPSuccess)
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
