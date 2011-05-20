#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_serving/base'

describe Puppet::FileServing::Base do
  it "should accept a path" do
    Puppet::FileServing::Base.new("/module/dir/file").path.should == "/module/dir/file"
  end

  it "should require that paths be fully qualified" do
    lambda { Puppet::FileServing::Base.new("module/dir/file") }.should raise_error(ArgumentError)
  end

  it "should allow specification of whether links should be managed" do
    Puppet::FileServing::Base.new("/module/dir/file", :links => :manage).links.should == :manage
  end

  it "should have a :source attribute" do
    file = Puppet::FileServing::Base.new("/module/dir/file")
    file.should respond_to(:source)
    file.should respond_to(:source=)
  end

  it "should consider :ignore links equivalent to :manage links" do
    Puppet::FileServing::Base.new("/module/dir/file", :links => :ignore).links.should == :manage
  end

  it "should fail if :links is set to anything other than :manage, :follow, or :ignore" do
    proc { Puppet::FileServing::Base.new("/module/dir/file", :links => :else) }.should raise_error(ArgumentError)
  end

  it "should allow links values to be set as strings" do
    Puppet::FileServing::Base.new("/module/dir/file", :links => "follow").links.should == :follow
  end

  it "should default to :manage for :links" do
    Puppet::FileServing::Base.new("/module/dir/file").links.should == :manage
  end

  it "should allow specification of a path" do
    FileTest.stubs(:exists?).returns(true)
    Puppet::FileServing::Base.new("/module/dir/file", :path => "/my/file").path.should == "/my/file"
  end

  it "should allow specification of a relative path" do
    FileTest.stubs(:exists?).returns(true)
    Puppet::FileServing::Base.new("/module/dir/file", :relative_path => "my/file").relative_path.should == "my/file"
  end

  it "should have a means of determining if the file exists" do
    Puppet::FileServing::Base.new("/blah").should respond_to(:exist?)
  end

  it "should correctly indicate if the file is present" do
    File.expects(:lstat).with("/my/file").returns(mock("stat"))
    Puppet::FileServing::Base.new("/my/file").exist?.should be_true
  end

  it "should correctly indicate if the file is absent" do
    File.expects(:lstat).with("/my/file").raises RuntimeError
    Puppet::FileServing::Base.new("/my/file").exist?.should be_false
  end

  describe "when setting the relative path" do
    it "should require that the relative path be unqualified" do
      @file = Puppet::FileServing::Base.new("/module/dir/file")
      FileTest.stubs(:exists?).returns(true)
      proc { @file.relative_path = "/qualified/file" }.should raise_error(ArgumentError)
    end
  end

  describe "when determining the full file path" do
    before do
      @file = Puppet::FileServing::Base.new("/this/file")
    end

    it "should return the path if there is no relative path" do
      @file.full_path.should == "/this/file"
    end

    it "should return the path if the relative_path is set to ''" do
      @file.relative_path = ""
      @file.full_path.should == "/this/file"
    end

    it "should return the path if the relative_path is set to '.'" do
      @file.relative_path = "."
      @file.full_path.should == "/this/file"
    end

    it "should return the path joined with the relative path if there is a relative path and it is not set to '/' or ''" do
      @file.relative_path = "not/qualified"
      @file.full_path.should == "/this/file/not/qualified"
    end

    it "should strip extra slashes" do
      file = Puppet::FileServing::Base.new("//this//file")
      file.full_path.should == "/this/file"
    end
  end

  describe "when stat'ing files" do
    before do
      @file = Puppet::FileServing::Base.new("/this/file")
    end

    it "should stat the file's full path" do
      @file.stubs(:full_path).returns("/this/file")
      File.expects(:lstat).with("/this/file").returns stub("stat", :ftype => "file")
      @file.stat
    end

    it "should fail if the file does not exist" do
      @file.stubs(:full_path).returns("/this/file")
      File.expects(:lstat).with("/this/file").raises(Errno::ENOENT)
      proc { @file.stat }.should raise_error(Errno::ENOENT)
    end

    it "should use :lstat if :links is set to :manage" do
      File.expects(:lstat).with("/this/file").returns stub("stat", :ftype => "file")
      @file.stat
    end

    it "should use :stat if :links is set to :follow" do
      File.expects(:stat).with("/this/file").returns stub("stat", :ftype => "file")
      @file.links = :follow
      @file.stat
    end
  end
end
