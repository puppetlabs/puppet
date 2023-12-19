# frozen_string_literal: true

require_relative '../../../puppet/file_serving/content'
require_relative '../../../puppet/indirector/file_content'
require_relative '../../../puppet/indirector/direct_file_server'

class Puppet::Indirector::FileContent::File < Puppet::Indirector::DirectFileServer
  desc "Retrieve file contents from disk."
end
