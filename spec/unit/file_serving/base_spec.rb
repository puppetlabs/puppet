#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/base'

describe Puppet::FileServing::Base do
  let(:path) { File.expand_path('/module/dir/file') }
  let(:file) { File.expand_path('/my/file') }

  it "should accept a path" do
    Puppet::FileServing::Base.new(path).path.should == path
  end

  it "should require that paths be fully qualified" do
    lambda { Puppet::FileServing::Base.new("module/dir/file") }.should raise_error(ArgumentError)
  end

  it "should allow specification of whether links should be managed" do
    Puppet::FileServing::Base.new(path, :links => :manage).links.should == :manage
  end

  it "should have a :source attribute" do
    file = Puppet::FileServing::Base.new(path)
    file.should respond_to(:source)
    file.should respond_to(:source=)
  end

  it "should consider :ignore links equivalent to :manage links" do
    Puppet::FileServing::Base.new(path, :links => :ignore).links.should == :manage
  end

  it "should fail if :links is set to anything other than :manage, :follow, or :ignore" do
    proc { Puppet::FileServing::Base.new(path, :links => :else) }.should raise_error(ArgumentError)
  end

  it "should allow links values to be set as strings" do
    Puppet::FileServing::Base.new(path, :links => "follow").links.should == :follow
  end

  it "should default to :manage for :links" do
    Puppet::FileServing::Base.new(path).links.should == :manage
  end

  it "should allow specification of a path" do
    Puppet::FileSystem.stubs(:exist?).returns(true)
    Puppet::FileServing::Base.new(path, :path => file).path.should == file
  end

  it "should allow specification of a relative path" do
    Puppet::FileSystem.stubs(:exist?).returns(true)
    Puppet::FileServing::Base.new(path, :relative_path => "my/file").relative_path.should == "my/file"
  end

  it "should have a means of determining if the file exists" do
    Puppet::FileServing::Base.new(file).should respond_to(:exist?)
  end

  it "should correctly indicate if the file is present" do
    Puppet::FileSystem.expects(:lstat).with(file).returns stub('stat')
    Puppet::FileServing::Base.new(file).exist?.should be_true
  end

  it "should correctly indicate if the file is absent" do
    Puppet::FileSystem.expects(:lstat).with(file).raises RuntimeError
    Puppet::FileServing::Base.new(file).exist?.should be_false
  end

  describe "when setting the relative path" do
    it "should require that the relative path be unqualified" do
      @file = Puppet::FileServing::Base.new(path)
      Puppet::FileSystem.stubs(:exist?).returns(true)
      proc { @file.relative_path = File.expand_path("/qualified/file") }.should raise_error(ArgumentError)
    end
  end

  describe "when determining the full file path" do
    let(:path) { File.expand_path('/this/file') }
    let(:file) { Puppet::FileServing::Base.new(path) }

    it "should return the path if there is no relative path" do
      file.full_path.should == path
    end

    it "should return the path if the relative_path is set to ''" do
      file.relative_path = ""
      file.full_path.should == path
    end

    it "should return the path if the relative_path is set to '.'" do
      file.relative_path = "."
      file.full_path.should == path
    end

    it "should return the path joined with the relative path if there is a relative path and it is not set to '/' or ''" do
      file.relative_path = "not/qualified"
      file.full_path.should == File.join(path, "not/qualified")
    end

    it "should strip extra slashes" do
      file = Puppet::FileServing::Base.new(File.join(File.expand_path('/'), "//this//file"))
      file.full_path.should == path
    end
  end

  describe "when handling a UNC file path on Windows" do
    let(:path) { '//server/share/filename' }
    let(:file) { Puppet::FileServing::Base.new(path) }

    it "should preserve double slashes at the beginning of the path" do
      Puppet.features.stubs(:microsoft_windows?).returns(true)
      file.full_path.should == path
    end

    it "should strip double slashes not at the beginning of the path" do
      Puppet.features.stubs(:microsoft_windows?).returns(true)
      file = Puppet::FileServing::Base.new('//server//share//filename')
      file.full_path.should == path
    end
  end


  describe "when stat'ing files" do
    let(:path) { File.expand_path('/this/file') }
    let(:file) { Puppet::FileServing::Base.new(path) }
    let(:stat) { stub('stat', :ftype => 'file' ) }
    let(:stubbed_file) { stub(path, :stat => stat, :lstat => stat)}

    it "should stat the file's full path" do
      Puppet::FileSystem.expects(:lstat).with(path).returns stat
      file.stat
    end

    it "should fail if the file does not exist" do
      Puppet::FileSystem.expects(:lstat).with(path).raises(Errno::ENOENT)
      proc { file.stat }.should raise_error(Errno::ENOENT)
    end

    it "should use :lstat if :links is set to :manage" do
      Puppet::FileSystem.expects(:lstat).with(path).returns stubbed_file
      file.stat
    end

    it "should use :stat if :links is set to :follow" do
      Puppet::FileSystem.expects(:stat).with(path).returns stubbed_file
      file.links = :follow
      file.stat
    end
  end

  describe "#absolute?" do
    it "should be accept POSIX paths" do
      Puppet::FileServing::Base.should be_absolute('/')
    end

    it "should accept Windows paths on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns(true)
      Puppet.features.stubs(:posix?).returns(false)

      Puppet::FileServing::Base.should be_absolute('c:/foo')
    end

    it "should reject Windows paths on POSIX" do
      Puppet.features.stubs(:microsoft_windows?).returns(false)

      Puppet::FileServing::Base.should_not be_absolute('c:/foo')
    end
  end
end
