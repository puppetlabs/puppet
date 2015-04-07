require 'puppet/file_serving/metadata'
require 'puppet/indirector/s3'

class Puppet::Indirector::FileContent::S3 < Puppet::Indirector::S3
    desc "Retrieve file contents from S3."

    include Puppet::FileServing::TerminusHelper

    @s3_method = :get_object

    def find(request)
      response = super
      model.from_binary(response.body)
    end
end
