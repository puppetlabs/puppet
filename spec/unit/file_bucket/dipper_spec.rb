#! /usr/bin/env ruby -S rspec
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
      @plaintext = 'my\r\ncontents'
      # These are written out, rather than calculated, so that you the reader
      # can see more simply what behavior this spec is specifying.
      @checksums = {
        'md5'    => 'f0d7d4e480ad698ed56aeec8b6bd6dea',
        'sha256' => '409a11465ed0938227128b1756c677a8480a8b84814f1963853775e15a74d4b4',
      }
      @dirs      = {
        'md5'    => 'f/0/d/7/d/4/e/4/f0d7d4e480ad698ed56aeec8b6bd6dea',
        'sha256' => '4/0/9/a/1/1/4/6/409a11465ed0938227128b1756c677a8480a8b84814f1963853775e15a74d4b4',
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
    
      describe "#restore" do
        shared_examples_for "a restorable file" do
          let(:contents) { "my\ncontents" }
          let(:md5) { Digest::MD5.hexdigest(contents) }
          let(:dest) { tmpfile('file_bucket_dest') }
    
          it "should restore the file" do
            request = nil
    
            klass.any_instance.expects(:find).with { |r| request = r }.returns(Puppet::FileBucket::File.new(contents))
    
            dipper.restore(dest, md5).should == md5
            Digest::MD5.hexdigest(IO.binread(dest)).should == md5
    
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
  end
end
