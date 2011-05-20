#!/usr/bin/env rspec
require 'spec_helper'

property = Puppet::Type.type(:file).attrclass(:ensure)

describe property do
  before do
    # Wow that's a messy interface to the resource.
    @resource = stub 'resource', :[] => nil, :[]= => nil, :property => nil, :newattr => nil, :parameter => nil, :replace? => true
    @resource.stubs(:[]).returns "foo"
    @resource.stubs(:[]).with(:path).returns "/my/file"
    @ensure = property.new :resource => @resource
  end

  it "should be a subclass of Ensure" do
    property.superclass.must == Puppet::Property::Ensure
  end

  describe "when retrieving the current state" do
    it "should return :absent if the file does not exist" do
      @ensure = property.new(:resource => @resource)
      @resource.expects(:stat).returns nil

      @ensure.retrieve.should == :absent
    end

    it "should return the current file type if the file exists" do
      @ensure = property.new(:resource => @resource)
      stat = mock 'stat', :ftype => "directory"
      @resource.expects(:stat).returns stat

      @ensure.retrieve.should == :directory
    end
  end

  describe "when testing whether :ensure is in sync" do
    before do
      @ensure = property.new(:resource => @resource)
      @stat = stub 'stat', :ftype => "file"
    end

    it "should always be in sync if replace is 'false' unless the file is missing" do
      @ensure.should = :file
      @resource.expects(:replace?).returns false
      @ensure.safe_insync?(:link).should be_true
    end

    it "should be in sync if :ensure is set to :absent and the file does not exist" do
      @ensure.should = :absent

      @ensure.must be_safe_insync(:absent)
    end

    it "should not be in sync if :ensure is set to :absent and the file exists" do
      @ensure.should = :absent

      @ensure.should_not be_safe_insync(:file)
    end

    it "should be in sync if a normal file exists and :ensure is set to :present" do
      @ensure.should = :present

      @ensure.must be_safe_insync(:file)
    end

    it "should be in sync if a directory exists and :ensure is set to :present" do
      @ensure.should = :present

      @ensure.must be_safe_insync(:directory)
    end

    it "should be in sync if a symlink exists and :ensure is set to :present" do
      @ensure.should = :present

      @ensure.must be_safe_insync(:link)
    end

    it "should not be in sync if :ensure is set to :file and a directory exists" do
      @ensure.should = :file

      @ensure.should_not be_safe_insync(:directory)
    end
  end
end
