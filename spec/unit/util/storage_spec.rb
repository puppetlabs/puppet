#!/usr/bin/env rspec
require 'spec_helper'

require 'yaml'
require 'puppet/util/storage'

describe Puppet::Util::Storage do
  include PuppetSpec::Files

  before(:all) do
    @basepath = Puppet.features.posix? ? "/somepath" : "C:/somepath"
    Puppet[:statedir] = tmpdir("statedir")
  end

  after(:all) do
    Puppet.settings.clear
  end

  before(:each) do
    Puppet::Util::Storage.clear
  end

  describe "when caching a symbol" do
    it "should return an empty hash" do
      Puppet::Util::Storage.cache(:yayness).should == {}
      Puppet::Util::Storage.cache(:more_yayness).should == {}
    end

    it "should add the symbol to its internal state" do
      Puppet::Util::Storage.cache(:yayness)
      Puppet::Util::Storage.state.should == {:yayness=>{}}
    end

    it "should not clobber existing state when caching additional objects" do
      Puppet::Util::Storage.cache(:yayness)
      Puppet::Util::Storage.state.should == {:yayness=>{}}
      Puppet::Util::Storage.cache(:bubblyness)
      Puppet::Util::Storage.state.should == {:yayness=>{},:bubblyness=>{}}
    end
  end

  describe "when caching a Puppet::Type" do
    before(:all) do
      @file_test = Puppet::Type.type(:file).new(:name => @basepath+"/yayness", :check => %w{checksum type})
      @exec_test = Puppet::Type.type(:exec).new(:name => @basepath+"/bin/ls /yayness")
    end

    it "should return an empty hash" do
      Puppet::Util::Storage.cache(@file_test).should == {}
      Puppet::Util::Storage.cache(@exec_test).should == {}
    end

    it "should add the resource ref to its internal state" do
      Puppet::Util::Storage.state.should == {}
      Puppet::Util::Storage.cache(@file_test)
      Puppet::Util::Storage.state.should == {"File[#{@basepath}/yayness]"=>{}}
      Puppet::Util::Storage.cache(@exec_test)
      Puppet::Util::Storage.state.should == {"File[#{@basepath}/yayness]"=>{}, "Exec[#{@basepath}/bin/ls /yayness]"=>{}}
    end
  end

  describe "when caching something other than a resource or symbol" do
    it "should cache by converting to a string" do
      data = Puppet::Util::Storage.cache(42)
      data[:yay] = true
      Puppet::Util::Storage.cache("42")[:yay].should be_true
    end
  end

  it "should clear its internal state when clear() is called" do
    Puppet::Util::Storage.cache(:yayness)
    Puppet::Util::Storage.state.should == {:yayness=>{}}
    Puppet::Util::Storage.clear
    Puppet::Util::Storage.state.should == {}
  end

  describe "when loading from the state file" do
    before do
      Puppet.settings.stubs(:use).returns(true)
    end

    describe "when the state file/directory does not exist" do
      before(:each) do
        transient = Tempfile.new('storage_test')
        @path = transient.path()
        transient.close!()
      end

      it "should not fail to load()" do
        FileTest.exists?(@path).should be_false
        Puppet[:statedir] = @path
        proc { Puppet::Util::Storage.load }.should_not raise_error
        Puppet[:statefile] = @path
        proc { Puppet::Util::Storage.load }.should_not raise_error
      end

      it "should not lose its internal state when load() is called" do
        FileTest.exists?(@path).should be_false

        Puppet::Util::Storage.cache(:yayness)
        Puppet::Util::Storage.state.should == {:yayness=>{}}

        Puppet[:statefile] = @path
        proc { Puppet::Util::Storage.load }.should_not raise_error

        Puppet::Util::Storage.state.should == {:yayness=>{}}
      end
    end

    describe "when the state file/directory exists" do
      before(:each) do
        @state_file = Tempfile.new('storage_test')
        @saved_statefile = Puppet[:statefile]
        Puppet[:statefile] = @state_file.path
      end

      it "should overwrite its internal state if load() is called" do
        # Should the state be overwritten even if Puppet[:statefile] is not valid YAML?
        Puppet::Util::Storage.cache(:yayness)
        Puppet::Util::Storage.state.should == {:yayness=>{}}

        proc { Puppet::Util::Storage.load }.should_not raise_error
        Puppet::Util::Storage.state.should == {}
      end

      it "should restore its internal state if the state file contains valid YAML" do
        test_yaml = {'File["/yayness"]'=>{"name"=>{:a=>:b,:c=>:d}}}
        YAML.expects(:load).returns(test_yaml)

        proc { Puppet::Util::Storage.load }.should_not raise_error
        Puppet::Util::Storage.state.should == test_yaml
      end

      it "should initialize with a clear internal state if the state file does not contain valid YAML" do
        @state_file.write(:booness)
        @state_file.flush

        proc { Puppet::Util::Storage.load }.should_not raise_error
        Puppet::Util::Storage.state.should == {}
      end

      it "should raise an error if the state file does not contain valid YAML and cannot be renamed" do
        @state_file.write(:booness)
        @state_file.flush
        YAML.expects(:load).raises(Puppet::Error)
        File.expects(:rename).raises(SystemCallError)

        proc { Puppet::Util::Storage.load }.should raise_error
      end

      it "should attempt to rename the state file if the file is corrupted" do
        # We fake corruption by causing YAML.load to raise an exception
        YAML.expects(:load).raises(Puppet::Error)
        File.expects(:rename).at_least_once

        proc { Puppet::Util::Storage.load }.should_not raise_error
      end

      it "should fail gracefully on load() if the state file is not a regular file" do
        @state_file.close!()
        Dir.mkdir(Puppet[:statefile])

        proc { Puppet::Util::Storage.load }.should_not raise_error

        Dir.rmdir(Puppet[:statefile])
      end

      it "should fail gracefully on load() if it cannot get a read lock on the state file" do
        Puppet::Util::FileLocking.expects(:readlock).yields(false)
        test_yaml = {'File["/yayness"]'=>{"name"=>{:a=>:b,:c=>:d}}}
        YAML.expects(:load).returns(test_yaml)

        proc { Puppet::Util::Storage.load }.should_not raise_error
        Puppet::Util::Storage.state.should == test_yaml
      end

      after(:each) do
        @state_file.close!()
        Puppet[:statefile] = @saved_statefile
      end
    end
  end

  describe "when storing to the state file" do
    before(:each) do
      @state_file = Tempfile.new('storage_test')
      @saved_statefile = Puppet[:statefile]
      Puppet[:statefile] = @state_file.path
    end

    it "should create the state file if it does not exist" do
      @state_file.close!()
      FileTest.exists?(Puppet[:statefile]).should be_false
      Puppet::Util::Storage.cache(:yayness)

      proc { Puppet::Util::Storage.store }.should_not raise_error
      FileTest.exists?(Puppet[:statefile]).should be_true
    end

    it "should raise an exception if the state file is not a regular file" do
      @state_file.close!()
      Dir.mkdir(Puppet[:statefile])
      Puppet::Util::Storage.cache(:yayness)

      proc { Puppet::Util::Storage.store }.should raise_error

      Dir.rmdir(Puppet[:statefile])
    end

    it "should raise an exception if it cannot get a write lock on the state file" do
      Puppet::Util::FileLocking.expects(:writelock).yields(false)
      Puppet::Util::Storage.cache(:yayness)

      proc { Puppet::Util::Storage.store }.should raise_error
    end

    it "should load() the same information that it store()s" do
      Puppet::Util::Storage.cache(:yayness)

      Puppet::Util::Storage.state.should == {:yayness=>{}}
      proc { Puppet::Util::Storage.store }.should_not raise_error
      Puppet::Util::Storage.clear
      Puppet::Util::Storage.state.should == {}
      proc { Puppet::Util::Storage.load }.should_not raise_error
      Puppet::Util::Storage.state.should == {:yayness=>{}}
    end

    after(:each) do
      @state_file.close!()
      Puppet[:statefile] = @saved_statefile
    end
  end
end
