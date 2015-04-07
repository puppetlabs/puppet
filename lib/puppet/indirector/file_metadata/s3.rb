require 'puppet/file_serving/s3_metadata'
require 'puppet/indirector/s3'

class Puppet::Indirector::FileMetadata::S3 < Puppet::Indirector::S3
  desc "Retrieve file metadata via the s3 interface"

  @s3_method = :head_object

  def find(request)
    head = super

    Puppet::FileServing::S3Metadata.new(head)
  end

  def search(request)
    raise Puppet::Error, "cannot lookup multiple files"
  end
end
