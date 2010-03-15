#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucketFile::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::FileBucketFile::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
