#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::FileBucketFile::Rest.superclass).to equal(Puppet::Indirector::REST)
  end
end
