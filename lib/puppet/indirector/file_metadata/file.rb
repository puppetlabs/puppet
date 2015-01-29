require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileMetadata::File < Puppet::Indirector::DirectFileServer
  desc "Retrieve file metadata directly from the local filesystem."
end
