#!/usr/bin/env rspec
require 'spec_helper'

require 'pathname'

require 'puppet/file_bucket/dipper'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucket::Dipper do
  include PuppetSpec::Files

  def make_tmp_file(contents)
    file = tmpfile("file_bucket_file")
    File.open(file, 'w') { |f| f.write(contents) }
    file
  end

  it "should fail in an informative way when there are failures checking for the file on the server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => make_absolute("/my/bucket"))

    file = make_tmp_file('contents')
    Puppet::FileBucket::File.indirection.expects(:head).raises ArgumentError

    lambda { @dipper.backup(file) }.should raise_error(Puppet::Error)
  end

  it "should fail in an informative way when there are failures backing up to the server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => make_absolute("/my/bucket"))

    file = make_tmp_file('contents')
    Puppet::FileBucket::File.indirection.expects(:head).returns false
    Puppet::FileBucket::File.indirection.expects(:save).raises ArgumentError

    lambda { @dipper.backup(file) }.should raise_error(Puppet::Error)
  end

  it "should backup files to a local bucket", :fails_on_windows => true do
    Puppet[:bucketdir] = "/non/existent/directory"
    file_bucket = tmpdir("bucket")

    @dipper = Puppet::FileBucket::Dipper.new(:Path => file_bucket)

    file = make_tmp_file('my contents')
    checksum = "2975f560750e71c478b8e3b39a956adb"
    Digest::MD5.hexdigest('my contents').should == checksum

    @dipper.backup(file).should == checksum
    File.exists?("#{file_bucket}/2/9/7/5/f/5/6/0/2975f560750e71c478b8e3b39a956adb/contents").should == true
  end

  it "should not backup a file that is already in the bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    file = make_tmp_file('my contents')
    checksum = Digest::MD5.hexdigest('my contents')

    Puppet::FileBucket::File.indirection.expects(:head).returns true
    Puppet::FileBucket::File.indirection.expects(:save).never
    @dipper.backup(file).should == checksum
  end

  it "should retrieve files from a local bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    checksum = Digest::MD5.hexdigest('my contents')

    request = nil

    Puppet::FileBucketFile::File.any_instance.expects(:find).with{ |r| request = r }.once.returns(Puppet::FileBucket::File.new('my contents'))

    @dipper.getfile(checksum).should == 'my contents'

    request.key.should == "md5/#{checksum}"
  end

  it "should backup files to a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

    file = make_tmp_file('my contents')
    checksum = Digest::MD5.hexdigest('my contents')

    real_path = Pathname.new(file).realpath

    request1 = nil
    request2 = nil

    Puppet::FileBucketFile::Rest.any_instance.expects(:head).with { |r| request1 = r }.once.returns(nil)
    Puppet::FileBucketFile::Rest.any_instance.expects(:save).with { |r| request2 = r }.once

    @dipper.backup(file).should == checksum
    [request1, request2].each do |r|
      r.server.should == 'puppetmaster'
      r.port.should == 31337
      r.key.should == "md5/#{checksum}/#{real_path}"
    end
  end

  it "should retrieve files from a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

    checksum = Digest::MD5.hexdigest('my contents')

    request = nil

    Puppet::FileBucketFile::Rest.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new('my contents'))

    @dipper.getfile(checksum).should == "my contents"

    request.server.should == 'puppetmaster'
    request.port.should == 31337
    request.key.should == "md5/#{checksum}"
  end
end
