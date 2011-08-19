require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/file_server'

class Puppet::Indirector::FileContent::FileServer < Puppet::Indirector::FileServer
  desc "Retrieve file contents using Puppet's fileserver."
end
