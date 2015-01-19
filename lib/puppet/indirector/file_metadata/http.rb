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
      Puppet::FileServing::HttpMetadata.new(head)
    end
  end

  def search(request)
    raise Puppet::Error, "cannot lookup multiple files"
  end
end
