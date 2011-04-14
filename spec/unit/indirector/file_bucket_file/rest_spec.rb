#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::FileBucketFile::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
