#!/usr/bin/env rspec
require 'spec_helper'

source = Puppet::Type.type(:file).attrclass(:source)
describe Puppet::Type.type(:file).attrclass(:source) do
  before do
    # Wow that's a messy interface to the resource.
    @resource = stub 'resource', :[]= => nil, :property => nil, :catalog => stub("catalog", :dependent_data_expired? => false), :line => 0, :file => ''
  end

  it "should be a subclass of Parameter" do
    source.superclass.must == Puppet::Parameter
  end

  describe "when initializing" do
    it "should fail if the set values are not URLs" do
      s = source.new(:resource => @resource)
      URI.expects(:parse).with('foo').raises RuntimeError

      lambda { s.value = %w{foo} }.must raise_error(Puppet::Error)
    end

    it "should fail if the URI is not a local file, file URI, or puppet URI" do
      s = source.new(:resource => @resource)

      lambda { s.value = %w{http://foo/bar} }.must raise_error(Puppet::Error)
    end
  end

  it "should have a method for retrieving its metadata" do
    source.new(:resource => @resource).must respond_to(:metadata)
  end

  it "should have a method for setting its metadata" do
    source.new(:resource => @resource).must respond_to(:metadata=)
  end

  describe "when returning the metadata" do
    before do
      @metadata = stub 'metadata', :source= => nil
    end

    it "should return already-available metadata" do
      @source = source.new(:resource => @resource)
      @source.metadata = "foo"
      @source.metadata.should == "foo"
    end

    it "should return nil if no @should value is set and no metadata is available" do
      @source = source.new(:resource => @resource)
      @source.metadata.should be_nil
    end

    it "should collect its metadata using the Metadata class if it is not already set" do
      @source = source.new(:resource => @resource, :value => "/foo/bar")
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/foo/bar").returns @metadata
      @source.metadata
    end

    it "should use the metadata from the first found source" do
      metadata = stub 'metadata', :source= => nil
      @source = source.new(:resource => @resource, :value => ["/foo/bar", "/fee/booz"])
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/foo/bar").returns nil
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/fee/booz").returns metadata
      @source.metadata.should equal(metadata)
    end

    it "should store the found source as the metadata's source" do
      metadata = mock 'metadata'
      @source = source.new(:resource => @resource, :value => "/foo/bar")
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/foo/bar").returns metadata

      metadata.expects(:source=).with("/foo/bar")
      @source.metadata
    end

    it "should fail intelligently if an exception is encountered while querying for metadata" do
      @source = source.new(:resource => @resource, :value => "/foo/bar")
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/foo/bar").raises RuntimeError

      @source.expects(:fail).raises ArgumentError
      lambda { @source.metadata }.should raise_error(ArgumentError)
    end

    it "should fail if no specified sources can be found" do
      @source = source.new(:resource => @resource, :value => "/foo/bar")
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/foo/bar").returns nil

      @source.expects(:fail).raises RuntimeError

      lambda { @source.metadata }.should raise_error(RuntimeError)
    end

    it "should expire the metadata appropriately" do
      expirer = stub 'expired', :dependent_data_expired? => true

      metadata = stub 'metadata', :source= => nil
      Puppet::FileServing::Metadata.indirection.expects(:find).with("/fee/booz").returns metadata

      @source = source.new(:resource => @resource, :value => ["/fee/booz"])
      @source.metadata = "foo"

      @source.stubs(:expirer).returns expirer

      @source.metadata.should_not == "foo"
    end
  end

  it "should have a method for setting the desired values on the resource" do
    source.new(:resource => @resource).must respond_to(:copy_source_values)
  end

  describe "when copying the source values" do
    before do

      @resource = Puppet::Type.type(:file).new :path => "/foo/bar"

      @source = source.new(:resource => @resource)
      @metadata = stub 'metadata', :owner => 100, :group => 200, :mode => 123, :checksum => "{md5}asdfasdf", :ftype => "file"
      @source.stubs(:metadata).returns @metadata
    end

    it "should fail if there is no metadata" do
      @source.stubs(:metadata).returns nil
      @source.expects(:devfail).raises ArgumentError
      lambda { @source.copy_source_values }.should raise_error(ArgumentError)
    end

    it "should set :ensure to the file type" do
      @metadata.stubs(:ftype).returns "file"

      @source.copy_source_values
      @resource[:ensure].must == :file
    end

    it "should not set 'ensure' if it is already set to 'absent'" do
      @metadata.stubs(:ftype).returns "file"

      @resource[:ensure] = :absent
      @source.copy_source_values
      @resource[:ensure].must == :absent
    end

    describe "and the source is a file" do
      before do
        @metadata.stubs(:ftype).returns "file"
      end

      it "should copy the metadata's owner, group, checksum, and mode to the resource if they are not set on the resource" do
        Puppet.features.expects(:root?).returns true

        @source.copy_source_values

        @resource[:owner].must == 100
        @resource[:group].must == 200
        @resource[:mode].must == "173"

        # Metadata calls it checksum, we call it content.
        @resource[:content].must == @metadata.checksum
      end

      it "should not copy the metadata's owner to the resource if it is already set" do
        @resource[:owner] = 1
        @resource[:group] = 2
        @resource[:mode] = 3
        @resource[:content] = "foobar"

        @source.copy_source_values

        @resource[:owner].must == 1
        @resource[:group].must == 2
        @resource[:mode].must == "3"
        @resource[:content].should_not == @metadata.checksum
      end

      describe "and puppet is not running as root" do
        it "should not try to set the owner" do
          Puppet.features.expects(:root?).returns false

          @source.copy_source_values
          @resource[:owner].should be_nil
        end
      end
    end

    describe "and the source is a link" do
      it "should set the target to the link destination" do
        @metadata.stubs(:ftype).returns "link"
        @metadata.stubs(:links).returns "manage"
        @resource.stubs(:[])
        @resource.stubs(:[]=)

        @metadata.expects(:destination).returns "/path/to/symlink"

        @resource.expects(:[]=).with(:target, "/path/to/symlink")
        @source.copy_source_values
      end
    end
  end

  it "should have a local? method" do
    source.new(:resource => @resource).must be_respond_to(:local?)
  end

  context "when accessing source properties" do
    before(:each) do
      @source = source.new(:resource => @resource)
      @metadata = stub_everything
      @source.stubs(:metadata).returns(@metadata)
    end

    describe "for local sources" do
      before(:each) do
        @metadata.stubs(:ftype).returns "file"
        @metadata.stubs(:source).returns("file:///path/to/source")
      end

      it "should be local" do
        @source.must be_local
      end

      it "should be local if there is no scheme" do
        @metadata.stubs(:source).returns("/path/to/source")
        @source.must be_local
      end

      it "should be able to return the metadata source full path" do
        @source.full_path.should == "/path/to/source"
      end
    end

    describe "for remote sources" do
      before(:each) do
        @metadata.stubs(:ftype).returns "file"
        @metadata.stubs(:source).returns("puppet://server:8192/path/to/source")
      end

      it "should not be local" do
        @source.should_not be_local
      end

      it "should be able to return the metadata source full path" do
        @source.full_path.should == "/path/to/source"
      end

      it "should be able to return the source server" do
        @source.server.should == "server"
      end

      it "should be able to return the source port" do
        @source.port.should == 8192
      end

      describe "which don't specify server or port" do
        before(:each) do
          @metadata.stubs(:source).returns("puppet:///path/to/source")
        end

        it "should return the default source server" do
          Puppet.settings.expects(:[]).with(:server).returns("myserver")
          @source.server.should == "myserver"
        end

        it "should return the default source port" do
          Puppet.settings.expects(:[]).with(:masterport).returns(1234)
          @source.port.should == 1234
        end
      end
    end
  end

end
