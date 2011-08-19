require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/file_server'

class Puppet::Indirector::FileMetadata::FileServer < Puppet::Indirector::FileServer
  desc "Retrieve file metadata using Puppet's fileserver."
end
