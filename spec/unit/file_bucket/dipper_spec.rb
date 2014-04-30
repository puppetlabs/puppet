#! /usr/bin/env ruby
require 'spec_helper'

require 'pathname'

require 'puppet/file_bucket/dipper'
require 'puppet/indirector/file_bucket_file/rest'
require 'puppet/indirector/file_bucket_file/file'
require 'puppet/util/checksums'

shared_examples_for "a restorable file" do
  let(:dest) { tmpfile('file_bucket_dest') }

  describe "restoring the file" do
    with_digest_algorithms do
      it "should restore the file" do
        request = nil

        klass.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new(plaintext))

        dipper.restore(dest, checksum).should == checksum
        digest(Puppet::FileSystem.binread(dest)).should == checksum

        request.key.should == "#{digest_algorithm}/#{checksum}"
        request.server.should == server
        request.port.should == port
      end

      it "should skip restoring if existing file has the same checksum" do
        File.open(dest, 'wb') {|f| f.print(plaintext) }

        dipper.expects(:getfile).never
        dipper.restore(dest, checksum).should be_nil
      end

      it "should overwrite existing file if it has different checksum" do
        klass.any_instance.expects(:find).returns(Puppet::FileBucket::File.new(plaintext))

        File.open(dest, 'wb') {|f| f.print('other contents') }

        dipper.restore(dest, checksum).should == checksum
      end
    end
  end
end

describe Puppet::FileBucket::Dipper, :uses_checksums => true do
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

  describe "backing up and retrieving local files" do
    with_digest_algorithms do
      it "should backup files to a local bucket" do
        Puppet[:bucketdir] = "/non/existent/directory"
        file_bucket = tmpdir("bucket")

        @dipper = Puppet::FileBucket::Dipper.new(:Path => file_bucket)

        file = make_tmp_file(plaintext)
        digest(plaintext).should == checksum

        @dipper.backup(file).should == checksum
        Puppet::FileSystem.exist?("#{file_bucket}/#{bucket_dir}/contents").should == true
      end

      it "should not backup a file that is already in the bucket" do
        @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

        file = make_tmp_file(plaintext)

        Puppet::FileBucket::File.indirection.expects(:head).returns true
        Puppet::FileBucket::File.indirection.expects(:save).never
        @dipper.backup(file).should == checksum
      end

      it "should retrieve files from a local bucket" do
        @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

        request = nil

        Puppet::FileBucketFile::File.any_instance.expects(:find).with{ |r| request = r }.once.returns(Puppet::FileBucket::File.new(plaintext))

        @dipper.getfile(checksum).should == plaintext

        request.key.should == "#{digest_algorithm}/#{checksum}"
      end
    end
  end

  describe "backing up and retrieving remote files" do
    with_digest_algorithms do
      it "should backup files to a remote server" do
        @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

        file = make_tmp_file(plaintext)

        real_path = Pathname.new(file).realpath

        request1 = nil
        request2 = nil

        Puppet::FileBucketFile::Rest.any_instance.expects(:head).with { |r| request1 = r }.once.returns(nil)
        Puppet::FileBucketFile::Rest.any_instance.expects(:save).with { |r| request2 = r }.once

        @dipper.backup(file).should == checksum
        [request1, request2].each do |r|
          r.server.should == 'puppetmaster'
          r.port.should == 31337
          r.key.should == "#{digest_algorithm}/#{checksum}/#{real_path}"
        end
      end

      it "should retrieve files from a remote server" do
        @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

        request = nil

        Puppet::FileBucketFile::Rest.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new(plaintext))

        @dipper.getfile(checksum).should == plaintext

        request.server.should == 'puppetmaster'
        request.port.should == 31337
        request.key.should == "#{digest_algorithm}/#{checksum}"
      end
    end
  end

  describe "#restore" do

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

