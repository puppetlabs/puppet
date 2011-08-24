require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileContent::File < Puppet::Indirector::DirectFileServer
  desc "Retrieve file contents from disk."
end
