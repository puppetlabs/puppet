require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileMetadata::File < Puppet::Indirector::DirectFileServer
  desc "Retrieve file metadata directly from the local filesystem."

  def find(request)
    return unless data = super
    data.collect

    data
  end

  def search(request)
    return unless result = super

    result.each { |instance| instance.collect }

    result
  end
end
