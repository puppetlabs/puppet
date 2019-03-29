require 'spec_helper'

require 'puppet/indirector/file_bucket_file/selector'
require 'puppet/indirector/file_bucket_file/file'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Selector do
  %w[head find save search destroy].each do |method|
    describe "##{method}" do
      it "should proxy to rest terminus for https requests" do
        request = double('request', :protocol => 'https')

        expect_any_instance_of(Puppet::FileBucketFile::Rest).to receive(method).with(request)

        subject.send(method, request)
      end

      it "should proxy to file terminus for other requests" do
        request = double('request', :protocol => 'file')

        expect_any_instance_of(Puppet::FileBucketFile::File).to receive(method).with(request)

        subject.send(method, request)
      end
    end
  end
end

