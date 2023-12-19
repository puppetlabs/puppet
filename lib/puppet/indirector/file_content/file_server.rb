# frozen_string_literal: true

require_relative '../../../puppet/file_serving/content'
require_relative '../../../puppet/indirector/file_content'
require_relative '../../../puppet/indirector/file_server'

class Puppet::Indirector::FileContent::FileServer < Puppet::Indirector::FileServer
  desc "Retrieve file contents using Puppet's fileserver."
end
