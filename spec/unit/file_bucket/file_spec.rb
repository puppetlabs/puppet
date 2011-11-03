#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/file_bucket/file'


describe Puppet::FileBucket::File do
  include PuppetSpec::Files

  before do
    # this is the default from spec_helper, but it keeps getting reset at odd times
    @bucketdir = tmpdir('bucket')
    Puppet[:bucketdir] = @bucketdir

    @digests = {
      "md5"    => "4a8ec4fa5f01b4ab1a0ab8cbccb709f0",
      "sha256" => "7bb6f9f7a47a63e684925af3608c059edcc371eb81188c48c9714896fb1091fd",
    }
    @checksums = {
      "md5"    => "{md5}4a8ec4fa5f01b4ab1a0ab8cbccb709f0",
      "sha256" => "{sha256}7bb6f9f7a47a63e684925af3608c059edcc371eb81188c48c9714896fb1091fd",
    }
    @dirs = {
      "md5"    => File.join(@bucketdir, "4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0"),
      "sha256" => File.join(@bucketdir, "7/b/b/6/f/9/f/7/7bb6f9f7a47a63e684925af3608c059edcc371eb81188c48c9714896fb1091fd"),
    }
    @contents = "file contents"
  end

  it "should have a to_s method to return the contents" do
    Puppet::FileBucket::File.new(@contents).to_s.should == @contents
  end

  it "should raise an error if changing content" do
    x = Puppet::FileBucket::File.new("first")
    expect { x.contents = "new" }.to raise_error(NoMethodError, /undefined method .contents=/)
  end

  it "should require contents to be a string" do
    expect { Puppet::FileBucket::File.new(5) }.to raise_error(ArgumentError, /contents must be a String, got a Fixnum$/)
  end

  it "should complain about options other than :bucket_path" do
    expect {
      Puppet::FileBucket::File.new('5', :crazy_option => 'should not be passed')
    }.to raise_error(ArgumentError, /Unknown option\(s\): crazy_option/)
  end

  it "should set the contents appropriately" do
    Puppet::FileBucket::File.new(@contents).contents.should == @contents
  end

  it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
    Puppet::FileBucket::File.new(@contents).checksum_type.should == "md5"
  end

  it "should support multiple checksum algorithms" do
    oda = Puppet[:digest_algorithm]
    Puppet[:digest_algorithm] = 'sha256'
    p = Puppet::FileBucket::File.new(@contents)
    p.checksum_type.should == 'sha256'
    Puppet[:digest_algorithm] = oda
  end

  it "should reject unknown checksum algorithms" do
    proc {
      oda = Puppet[:digest_algorithm]
      begin
        Puppet[:digest_algorithm] = 'wefoijwefoij23f02j'
        Puppet::FileBucket::File.new(@contents)
      ensure
        Puppet[:digest_algorithm] = oda
      end
    }.should raise_error(ArgumentError)
  end

  it "should calculate an MD5 checksum" do
    require 'digest/md5'
    @contents.should == 'file contents'
    Digest::MD5.hexdigest(@contents).should == @digests['md5']
    Puppet::FileBucket::File.new(@contents).checksum.should == @checksums['md5']
  end

  it "should calculate an SHA256 checksum" do
    oda = Puppet[:digest_algorithm]
    Puppet[:digest_algorithm] = 'sha256'
    Puppet::FileBucket::File.new(@contents).checksum.should == @checksums['sha256']
    Puppet[:digest_algorithm] = oda
  end

  describe "when using back-ends" do
    it "should redirect using Puppet::Indirector" do
      Puppet::Indirector::Indirection.instance(:file_bucket_file).model.should equal(Puppet::FileBucket::File)
    end

    it "should have a :save instance method" do
      Puppet::FileBucket::File.indirection.should respond_to(:save)
    end
  end

  it "should return a url-ish name" do
    Puppet::FileBucket::File.new(@contents).name.should == "md5/4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
  end

  it "should reject a url-ish name with an invalid checksum" do
    bucket = Puppet::FileBucket::File.new(@contents)
    expect { bucket.name = "sha1/4a8ec4fa5f01b4ab1a0ab8cbccb709f0/new/path" }.to raise_error(NoMethodError, /undefined method .name=/)
  end

  it "should convert the contents to PSON" do
    Puppet::FileBucket::File.new(@contents).to_pson.should == '{"contents":"file contents"}'
  end

  it "should load from PSON" do
    Puppet::FileBucket::File.from_pson({"contents"=>"file contents"}).contents.should == "file contents"
  end

  def make_bucketed_file(algorithm)
    FileUtils.mkdir_p(@dirs[algorithm])
    File.open("#{@dirs[algorithm]}/contents", 'w') { |f| f.write @contents }
  end

  describe "using the indirector's find method" do
    ['md5', 'sha256'].each do |algo|
      describe "using #{algo}" do
        before do
          Puppet[:digest_algorithm] = algo
        end

        it "should return nil if a file doesn't exist" do
          bucketfile = Puppet::FileBucket::File.indirection.find("#{algo}/#{@digests[algo]}")
          bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
          make_bucketed_file(algo)
          bucketfile = Puppet::FileBucket::File.indirection.find("#{algo}/#{@digests[algo]}")
          bucketfile.should_not == nil
        end

        describe "using RESTish digest notation" do
          it "should return nil if a file doesn't exist" do
            bucketfile = Puppet::FileBucket::File.indirection.find("#{algo}/#{@digests[algo]}")
            bucketfile.should == nil
          end

          it "should find a filebucket if the file exists" do
            make_bucketed_file(algo)
            bucketfile = Puppet::FileBucket::File.indirection.find("#{algo}/#{@digests[algo]}")
            bucketfile.should_not == nil
          end
        end
      end
    end
  end
end
