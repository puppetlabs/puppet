# frozen_string_literal: true

require_relative '../../../puppet/file_serving/metadata'
require_relative '../../../puppet/indirector/file_metadata'
require_relative '../../../puppet/indirector/file_server'

class Puppet::Indirector::FileMetadata::FileServer < Puppet::Indirector::FileServer
  desc "Retrieve file metadata using Puppet's fileserver."
end
