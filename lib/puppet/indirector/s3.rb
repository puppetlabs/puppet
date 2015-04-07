require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/terminus'
require 'aws-sdk-core' if Puppet.features.aws?

class Puppet::Indirector::S3 < Puppet::Indirector::Terminus

  class << self
    attr_accessor :s3_method
  end

  def find(request)
    if request.options[:region]
      # Region passed through from File Type
      s3 ||= ::Aws::S3::Client.new({region: request.options[:region]})
    else
      Puppet::Util::Warnings.warnonce "No user supplied region, connecting to eu-west-1"
      s3 ||= ::Aws::S3::Client.new({region: 'eu-west-1'})
    end

    Puppet.debug("S3 #{self.class.s3_method.to_s} request to #{request.uri}")

    begin
      s3.send(self.class.s3_method, bucket: request.bucket, key: request.key)
    rescue Aws::Errors::MissingCredentialsError
      raise Puppet::Error, "AWS SDK is unable to source credentials to connect to #{request.uri}"

    rescue Aws::S3::Errors::Forbidden => e
      raise Puppet::Error, "Issue connecting using the provided AWS credentials to #{request.uri}"

    rescue Aws::S3::Errors::NotFound => e
      raise Puppet::Error, "Could not find key: <#{request.key}> in bucket: <#{request.bucket}> in region: <#{request.options[:region]}>"

    rescue Aws::S3::Errors::ServiceError => e
      raise Puppet::Error, "AWS::S3::Errors::ServiceError key: <#{request.key}> in bucket: <#{request.bucket}> in region: <#{request.options[:region]}>"

    rescue Aws::Errors::ServiceError => e
      raise Puppet::Error, "AWS::Errors::ServiceError key: <#{request.key}> in bucket: <#{request.bucket}> in region: <#{request.options[:region]}>"

    rescue NoMethodError => e
      raise Puppet::Error, "Unable to find bucket: <#{request.bucket}> in region <#{request.region ? request.region: "eu-west-1"}>"

    rescue => e
      raise Puppet::Error, "Issue trying to connect to S3 error: #{e.inspect}"

    end
  end
end
