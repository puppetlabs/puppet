require 'puppet/file_serving/terminus_helper'
require 'puppet/util/http_proxy'

class Puppet::Indirector::GenericHttp < Puppet::Indirector::Terminus
  desc "Retrieve data from a remote HTTP server."

  class <<self
    attr_accessor :http_method
  end

  def find(request)
    uri = URI(request.uri)
    method = self.class.http_method
    Puppet::Util::HttpProxy.request_with_redirects(uri,method)
  end
end
