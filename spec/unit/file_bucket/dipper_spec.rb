#!/usr/bin/env rspec
require 'spec_helper'

require 'pathname'

require 'puppet/file_bucket/dipper'
require 'puppet/indirector/file_bucket_file/rest'
require 'puppet/util/checksums'

ALGORITHMS_TO_TRY = [nil, 'md5', 'sha256']

ALGORITHMS_TO_TRY.each do |algo|
  describe "when using digest_algorithm #{algo || 'nil'}" do
    before do
      Puppet['digest_algorithm'] = algo
      # while we may set Puppet['digest_algorithm'] to nil, @algo is always
      # defined
      @algo      = algo || 'md5'
      @plaintext = 'my contents'
      # These are written out, rather than calculated, so that you the reader
      # can see more simply what behavior this spec is specifying.
      @checksums = {
        'md5'    => '2975f560750e71c478b8e3b39a956adb',
        'sha256' => '7b02ca7c8bf7970192642bd38149e693dc878c57aabce96d1d43c1c254ef3c7a',
      }
      @dirs      = {
        'md5'    => '2/9/7/5/f/5/6/0/2975f560750e71c478b8e3b39a956adb',
        'sha256' => '7/b/0/2/c/a/7/c/7b02ca7c8bf7970192642bd38149e693dc878c57aabce96d1d43c1c254ef3c7a',
      }
      def self.digest *args
        myDigest = Class.new do
          include Puppet::Util::Checksums
        end
        myDigest.new.method(@algo || 'md5').call *args
      end
    end

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

  it "should backup files to a local bucket" do
    Puppet[:bucketdir] = "/non/existent/directory"
    file_bucket = tmpdir("bucket")

    @dipper = Puppet::FileBucket::Dipper.new(:Path => file_bucket)

    file = make_tmp_file(@plaintext)
    digest(@plaintext).should == @checksums[@algo]

    @dipper.backup(file).should == @checksums[@algo]
    File.exists?("#{file_bucket}/#{@dirs[@algo]}/contents").should == true
  end

  it "should not backup a file that is already in the bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    file = make_tmp_file(@plaintext)

    Puppet::FileBucket::File.indirection.expects(:head).returns true
    Puppet::FileBucket::File.indirection.expects(:save).never
    @dipper.backup(file).should == @checksums[@algo]
  end

  it "should retrieve files from a local bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    request = nil

    Puppet::FileBucketFile::File.any_instance.expects(:find).with{ |r| request = r }.once.returns(Puppet::FileBucket::File.new(@plaintext))

    @dipper.getfile(@checksums[@algo]).should == @plaintext

    request.key.should == "#@algo/#{@checksums[@algo]}"
  end

  it "should backup files to a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

    file = make_tmp_file(@plaintext)

    real_path = Pathname.new(file).realpath

    request1 = nil
    request2 = nil

    Puppet::FileBucketFile::Rest.any_instance.expects(:head).with { |r| request1 = r }.once.returns(nil)
    Puppet::FileBucketFile::Rest.any_instance.expects(:save).with { |r| request2 = r }.once

    @dipper.backup(file).should == @checksums[@algo]
    [request1, request2].each do |r|
      r.server.should == 'puppetmaster'
      r.port.should == 31337
      r.key.should == "#@algo/#{@checksums[@algo]}/#{real_path}"
    end
  end

  it "should retrieve files from a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

    request = nil

    Puppet::FileBucketFile::Rest.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new('my contents'))

    @dipper.getfile(@checksums[@algo]).should == @plaintext

    request.server.should == 'puppetmaster'
    request.port.should == 31337
    request.key.should == "#@algo/#{@checksums[@algo]}"
  end
end
end
end
