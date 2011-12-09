#!/usr/bin/env rspec
require 'spec_helper'

require 'pathname'

require 'puppet/file_bucket/dipper'
require 'puppet/indirector/file_bucket_file/rest'

describe Puppet::FileBucket::Dipper do
  include PuppetSpec::Files

  def make_tmp_file(contents)
    file = tmpfile("file_bucket_file")
    File.open(file, 'wb') { |f| f.write(contents) }
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

    file = make_tmp_file("my\r\ncontents")
    checksum = "f0d7d4e480ad698ed56aeec8b6bd6dea"
    Digest::MD5.hexdigest("my\r\ncontents").should == checksum

    @dipper.backup(file).should == checksum
    File.exists?("#{file_bucket}/f/0/d/7/d/4/e/4/f0d7d4e480ad698ed56aeec8b6bd6dea/contents").should == true
  end

  it "should not backup a file that is already in the bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    file = make_tmp_file("my\r\ncontents")
    checksum = Digest::MD5.hexdigest("my\r\ncontents")

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

    file = make_tmp_file("my\r\ncontents")
    checksum = Digest::MD5.hexdigest("my\r\ncontents")

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

  describe "#restore" do
    shared_examples_for "a restorable file" do
      let(:contents) { "my\ncontents" }
      let(:md5) { Digest::MD5.hexdigest(contents) }
      let(:dest) { tmpfile('file_bucket_dest') }

      it "should restore the file" do
        request = nil

        klass.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new(contents))

        dipper.restore(dest, md5).should == md5
        Digest::MD5.hexdigest(Puppet::Util.binread(dest)).should == md5

        request.key.should == "md5/#{md5}"
        request.server.should == server
        request.port.should == port
      end

      it "should skip restoring if existing file has the same checksum" do
        crnl = "my\r\ncontents"
        File.open(dest, 'wb') {|f| f.print(crnl) }

        dipper.expects(:getfile).never
        dipper.restore(dest, Digest::MD5.hexdigest(crnl)).should be_nil
      end

      it "should overwrite existing file if it has different checksum" do
        klass.any_instance.expects(:find).returns(Puppet::FileBucket::File.new(contents))

        File.open(dest, 'wb') {|f| f.print('other contents') }

        dipper.restore(dest, md5).should == md5
      end
    end

    describe "when restoring from a remote server" do
      let(:klass) { Puppet::FileBucketFile::Rest }
      let(:server) { "puppetmaster" }
      let(:port) { 31337 }

      it_behaves_like "a restorable file" do
        let (:dipper) { Puppet::FileBucket::Dipper.new(:Server => server, :Port => port.to_s) }
      end
    end

    describe "when restoring from a local server" do
      let(:klass) { Puppet::FileBucketFile::File }
      let(:server) { nil }
      let(:port) { nil }

      it_behaves_like "a restorable file" do
        let (:dipper) { Puppet::FileBucket::Dipper.new(:Path => "/my/bucket") }
      end
    end
  end
end
