require 'puppet/file_serving/http_metadata'
require 'puppet/indirector/file_metadata'
require 'net/http'

require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileMetadata::Http < Puppet::Indirector::Plain
  desc "Retrieve file metadata from a remote HTTP server."

  def find(request)
    uri = URI( request.to_s.sub(/^.file_metadata.url=/,'') )
    Net::HTTP.start(uri.host, uri.port) do |http|
      response = http.request_head(uri.path)

      case response
      when Net::HTTPSuccess
        # proceed
      when Net::HTTPRedirection
        raise Puppet::Error, "redirection is not yet supported"
      else
        response.value()
      end

      Puppet::FileServing::HttpMetadata.new(response)
    end
  end

  def search(request)
    raise Puppet::Error, "cannot lookup multiple files"
  end
end
