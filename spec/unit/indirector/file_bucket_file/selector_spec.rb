#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_bucket_file/selector'
require 'puppet/indirector/file_bucket_file/file'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Selector do
  %w[head find save search destroy].each do |method|
    describe "##{method}" do
      it "should proxy to rest terminus for https requests" do
        request = stub 'request', :protocol => 'https'

        Puppet::FileBucketFile::Rest.any_instance.expects(method).with(request)

        subject.send(method, request)
      end

      it "should proxy to file terminus for other requests" do
        request = stub 'request', :protocol => 'file'

        Puppet::FileBucketFile::File.any_instance.expects(method).with(request)

        subject.send(method, request)
      end
    end
  end
end

