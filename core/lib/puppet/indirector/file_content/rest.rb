require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/rest'

class Puppet::Indirector::FileContent::Rest < Puppet::Indirector::REST
  desc "Retrieve file contents via a REST HTTP interface."

  use_srv_service(:fileserver)
end
