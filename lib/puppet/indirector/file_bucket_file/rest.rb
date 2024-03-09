# frozen_string_literal: true

require_relative '../../../puppet/indirector/rest'
require_relative '../../../puppet/file_bucket/file'

module Puppet::FileBucketFile
  class Rest < Puppet::Indirector::REST
    desc "This is a REST based mechanism to send/retrieve file to/from the filebucket"

    def head(request)
      session = Puppet.lookup(:http_session)
      api = session.route_to(:puppet)
      api.head_filebucket_file(
        request.key,
        environment: request.environment.to_s,
        bucket_path: request.options[:bucket_path]
      )
    rescue Puppet::HTTP::ResponseError => e
      return nil if e.response.code == 404

      raise convert_to_http_error(e.response)
    end

    def find(request)
      session = Puppet.lookup(:http_session)
      api = session.route_to(:puppet)
      _, filebucket_file = api.get_filebucket_file(
        request.key,
        environment: request.environment.to_s,
        bucket_path: request.options[:bucket_path],
        diff_with: request.options[:diff_with],
        list_all: request.options[:list_all],
        fromdate: request.options[:fromdate],
        todate: request.options[:todate]
      )
      filebucket_file
    rescue Puppet::HTTP::ResponseError => e
      raise convert_to_http_error(e.response)
    end

    def save(request)
      session = Puppet.lookup(:http_session)
      api = session.route_to(:puppet)
      api.put_filebucket_file(
        request.key,
        body: request.instance.render,
        environment: request.environment.to_s
      )
    rescue Puppet::HTTP::ResponseError => e
      raise convert_to_http_error(e.response)
    end
  end
end
