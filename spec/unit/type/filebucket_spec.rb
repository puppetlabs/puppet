require 'spec_helper'

describe Puppet::Type.type(:filebucket) do
  include PuppetSpec::Files

  describe "when validating attributes" do
    %w{name server port path}.each do |attr|
      it "should have a '#{attr}' parameter" do
        expect(Puppet::Type.type(:filebucket).attrtype(attr.intern)).to eq(:param)
      end
    end

    it "should have its 'name' attribute set as its namevar" do
      expect(Puppet::Type.type(:filebucket).key_attributes).to eq([:name])
    end
  end

  it "should use the clientbucketdir as the path by default path" do
    Puppet.settings[:clientbucketdir] = "/my/bucket"
    expect(Puppet::Type.type(:filebucket).new(:name => "main")[:path]).to eq(Puppet[:clientbucketdir])
  end

  it "should not have a default port" do
    Puppet.settings[:serverport] = 50
    expect(Puppet::Type.type(:filebucket).new(:name => "main")[:port]).to eq(nil)
  end

  it "should not have a default server" do
    Puppet.settings[:server] = "myserver"
    expect(Puppet::Type.type(:filebucket).new(:name => "main")[:server]).to eq(nil)
  end

  it "be local by default" do
    bucket = Puppet::Type.type(:filebucket).new :name => "main"

    expect(bucket.bucket).to be_local
  end

  describe "path" do
    def bucket(hash)
      Puppet::Type.type(:filebucket).new({:name => 'main'}.merge(hash))
    end

    it "should accept false as a value" do
      expect { bucket(:path => false) }.not_to raise_error
    end

    it "should accept true as a value" do
      expect { bucket(:path => true) }.not_to raise_error
    end

    it "should fail when given an array of values" do
      expect { bucket(:path => ['one', 'two']) }.
        to raise_error Puppet::Error, /only have one filebucket path/
    end

    %w{one ../one one/two}.each do |path|
      it "should fail if given a relative path of #{path.inspect}" do
        expect { bucket(:path => path) }.
          to raise_error Puppet::Error, /Filebucket paths must be absolute/
      end
    end

    it "should succeed if given an absolute path" do
      expect { bucket(:path => make_absolute('/tmp/bucket')) }.not_to raise_error
    end

    it "not be local if path is false" do
      expect(bucket(:path => false).bucket).not_to be_local
    end

    it "be local if both a path and a server are specified" do
      expect(bucket(:server => "puppet", :path => make_absolute("/my/path")).bucket).to be_local
    end
  end

  describe "when creating the filebucket" do
    before do
      @bucket = double('bucket', :name= => nil)
    end

    it "should use any provided path" do
      path = make_absolute("/foo/bar")
      bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => path
      expect(Puppet::FileBucket::Dipper).to receive(:new).with({:Path => path}).and_return(@bucket)
      bucket.bucket
    end

    it "should use any provided server and port" do
      bucket = Puppet::Type.type(:filebucket).new :name => "main", :server => "myserv", :port => "myport", :path => false
      expect(Puppet::FileBucket::Dipper).to receive(:new).with({:Server => "myserv", :Port => "myport"}).and_return(@bucket)
      bucket.bucket
    end

    it "should not try to guess server or port if the path is unset and no server is provided" do
      Puppet.settings[:server] = "myserv"
      Puppet.settings[:server_list] = ['server_list_0', 'server_list_1']
      expect(Puppet::FileBucket::Dipper).to receive(:new).with({:Server => nil, :Port => nil}).and_return(@bucket)

      bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => false
      bucket.bucket
    end
  end
end
