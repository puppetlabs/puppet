# frozen_string_literal: true

require_relative '../../../puppet/file_serving/metadata'
require_relative '../../../puppet/indirector/file_metadata'
require_relative '../../../puppet/indirector/direct_file_server'

class Puppet::Indirector::FileMetadata::File < Puppet::Indirector::DirectFileServer
  desc "Retrieve file metadata directly from the local filesystem."
end
