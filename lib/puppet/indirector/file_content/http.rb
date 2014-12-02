require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'net/http'

require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileContent::Http < Puppet::Indirector::Plain
  desc "Retrieve file contents from a remote HTTP server."

  def find(request)
    uri = URI( request.to_s.sub(%r{^/file_content/url=},'') )
    Net::HTTP.start(uri.host, uri.port) do |http|
      response = http.request_get(uri.path)

      case response
      when Net::HTTPSuccess
        # proceed
      when Net::HTTPRedirection
        raise Puppet::Error, "redirection is not yet supported"
      else
        # raise the error
        response.value()
      end

      model.from_binary(response.body)
    end
  end

end
