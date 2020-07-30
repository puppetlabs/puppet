require 'puppet/file_serving/terminus_helper'
require 'puppet/util/http_proxy'

class Puppet::Indirector::GenericHttp < Puppet::Indirector::Terminus
  desc "Retrieve data from a remote HTTP server."
end
