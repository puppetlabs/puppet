#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:filebucket) do
  describe "when validating attributes" do
    %w{name server port path}.each do |attr|
      it "should have a '#{attr}' parameter" do
        Puppet::Type.type(:filebucket).attrtype(attr.intern).should == :param
      end
    end

    it "should have its 'name' attribute set as its namevar" do
      Puppet::Type.type(:filebucket).key_attributes.should == [:name]
    end
  end

  it "should use the clientbucketdir as the path by default path" do
    Puppet.settings[:clientbucketdir] = "/my/bucket"
    Puppet::Type.type(:filebucket).new(:name => "main")[:path].should == Puppet[:clientbucketdir]
  end

  it "should use the masterport as the path by default port" do
    Puppet.settings[:masterport] = 50
    Puppet::Type.type(:filebucket).new(:name => "main")[:port].should == Puppet[:masterport]
  end

  it "should use the server as the path by default server" do
    Puppet.settings[:server] = "myserver"
    Puppet::Type.type(:filebucket).new(:name => "main")[:server].should == Puppet[:server]
  end

  it "be local by default" do
    bucket = Puppet::Type.type(:filebucket).new :name => "main"

    bucket.bucket.should be_local
  end

  it "not be local if path is false" do
    bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => false

    bucket.bucket.should_not be_local
  end

  it "be local if both a path and a server are specified" do
    bucket = Puppet::Type.type(:filebucket).new :name => "main", :server => "puppet", :path => "/my/path"

    bucket.bucket.should be_local
  end

  describe "when creating the filebucket" do
    before do
      @bucket = stub 'bucket', :name= => nil
    end

    it "should use any provided path" do
      bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => "/foo/bar"
      Puppet::FileBucket::Dipper.expects(:new).with(:Path => "/foo/bar").returns @bucket
      bucket.bucket
    end
    it "should use any provided server and port" do
      bucket = Puppet::Type.type(:filebucket).new :name => "main", :server => "myserv", :port => "myport", :path => false
      Puppet::FileBucket::Dipper.expects(:new).with(:Server => "myserv", :Port => "myport").returns @bucket
      bucket.bucket
    end

    it "should use the default server if the path is unset and no server is provided" do
      Puppet.settings[:server] = "myserv"
      bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => false
      Puppet::FileBucket::Dipper.expects(:new).with { |args| args[:Server] == "myserv" }.returns @bucket
      bucket.bucket
    end
  end
end
