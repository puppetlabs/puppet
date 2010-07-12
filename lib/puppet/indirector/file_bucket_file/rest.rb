require 'puppet/indirector/rest'
require 'puppet/file_bucket/file'

module Puppet::FileBucketFile
  class Rest < Puppet::Indirector::REST
    desc "This is a REST based mechanism to send/retrieve file to/from the filebucket"
  end
end
