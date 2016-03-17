#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confine/exists'

describe Puppet::Confine::Exists do
  before do
    @confine = Puppet::Confine::Exists.new("/my/file")
    @confine.label = "eh"
  end

  it "should be named :exists" do
    Puppet::Confine::Exists.name.should == :exists
  end
  
  it "should not pass if exists is nil" do
    confine = Puppet::Confine::Exists.new(nil)
    confine.label = ":exists => nil"
    confine.expects(:pass?).with(nil)
    confine.should_not be_valid
  end

  it "should use the 'pass?' method to test validity" do
    @confine.expects(:pass?).with("/my/file")
    @confine.valid?
  end

  it "should return false if the value is false" do
    @confine.pass?(false).should be_false
  end

  it "should return false if the value does not point to a file" do
    Puppet::FileSystem.expects(:exist?).with("/my/file").returns false
    @confine.pass?("/my/file").should be_false
  end

  it "should return true if the value points to a file" do
    Puppet::FileSystem.expects(:exist?).with("/my/file").returns true
    @confine.pass?("/my/file").should be_true
  end

  it "should produce a message saying that a file is missing" do
    @confine.message("/my/file").should be_include("does not exist")
  end

  describe "and the confine is for binaries" do
    before { @confine.stubs(:for_binary).returns true }
    it "should use its 'which' method to look up the full path of the file" do
      @confine.expects(:which).returns nil
      @confine.pass?("/my/file")
    end

    it "should return false if no executable can be found" do
      @confine.expects(:which).with("/my/file").returns nil
      @confine.pass?("/my/file").should be_false
    end

    it "should return true if the executable can be found" do
      @confine.expects(:which).with("/my/file").returns "/my/file"
      @confine.pass?("/my/file").should be_true
    end
  end

  it "should produce a summary containing all missing files" do
    Puppet::FileSystem.stubs(:exist?).returns true
    Puppet::FileSystem.expects(:exist?).with("/two").returns false
    Puppet::FileSystem.expects(:exist?).with("/four").returns false

    confine = Puppet::Confine::Exists.new %w{/one /two /three /four}
    confine.summary.should == %w{/two /four}
  end

  it "should summarize multiple instances by returning a flattened array of their summaries" do
    c1 = mock '1', :summary => %w{one}
    c2 = mock '2', :summary => %w{two}
    c3 = mock '3', :summary => %w{three}

    Puppet::Confine::Exists.summarize([c1, c2, c3]).should == %w{one two three}
  end
end
