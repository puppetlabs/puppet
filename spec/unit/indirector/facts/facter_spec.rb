#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/facts/facter'

describe Puppet::Node::Facts::Facter do
  before :each do
    ::Facter.stubs(:clear) # For speed reasons
    ::Facter.stubs(:loadfacts) # For speed reasons

    @facter = Puppet::Node::Facts::Facter.new
    Facter.stubs(:to_hash).returns({})
    @name = "me"
    @request = stub 'request', :key => @name
  end

  it "should be a subclass of the Code terminus" do
    Puppet::Node::Facts::Facter.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    Puppet::Node::Facts::Facter.doc.should_not be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    Puppet::Node::Facts::Facter.indirection.should equal(indirection)
  end

  it "should have its name set to :facter" do
    Puppet::Node::Facts::Facter.name.should == :facter
  end

  it "should load facts on initialization" do
    Puppet::Node::Facts::Facter.any_instance.expects(:load)
    Puppet::Node::Facts::Facter.new
  end

  describe "when finding facts" do
    it "should return a Facts instance" do
      @facter.find(@request).should be_instance_of(Puppet::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      @facter.find(@request).name.should == @name
    end

    it "should return the Facter facts as the values in the Facts instance" do
      Facter.expects(:to_hash).returns("one" => "two")
      facts = @facter.find(@request)
      facts.values["one"].should == "two"
    end

    it "should add local facts" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:add_local_facts)

      @facter.find(@request)
    end

    it "should convert all facts into strings" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:stringify)

      @facter.find(@request)
    end

    it "should call the downcase hook" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:downcase_if_necessary)

      @facter.find(@request)
    end
  end

  describe "when saving facts" do
    it "should fail" do
      proc { @facter.save(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  describe "when destroying facts" do

    it "should fail" do
      proc { @facter.destroy(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  describe "when loading facts from disk" do
    before do
      @facter = Puppet::Node::Facts::Facter.new
      ::Facter.stubs(:clear) # For speed reasons
      ::Facter.stubs(:loadfacts) # For speed reasons
    end

    it "should clear existing facts then call top-level loading in Facter" do
      ::Facter.expects(:clear)
      ::Facter.expects(:loadfacts)
      @facter.load
    end

    it "should skip files when asked to load a directory" do
      FileTest.expects(:directory?).with("myfile").returns false

      @facter.load_facts_in_dir("myfile")
    end

    it "should load each ruby file when asked to load a directory" do
      FileTest.expects(:directory?).with("mydir").returns true
      Dir.expects(:chdir).with("mydir").yields

      Dir.expects(:glob).with("*.rb").returns %w{a.rb b.rb}

      Kernel.expects(:load).with("a.rb")
      Kernel.expects(:load).with("b.rb")

      @facter.load_facts_in_dir("mydir")
    end

    describe "when loading fact plugins from disk" do
      it "should load each directory in the Fact path" do
        Puppet.settings.stubs(:value).returns "foo"
        Puppet.settings.expects(:value).with(:factpath).returns("one#{File::PATH_SEPARATOR}two")

        @facter.expects(:load_facts_in_dir).with("one")
        @facter.expects(:load_facts_in_dir).with("two")

        @facter.load
      end

      it "should load all facts from the modules" do
        Puppet.settings.stubs(:value).returns "foo"
        @facter.stubs(:load_facts_in_dir)

        Puppet.settings.expects(:value).with(:modulepath).returns("one#{File::PATH_SEPARATOR}two")

        Dir.stubs(:glob).returns []
        Dir.expects(:glob).with("one/*/lib/facter").returns %w{oneA oneB}
        Dir.expects(:glob).with("two/*/lib/facter").returns %w{twoA twoB}

        @facter.expects(:load_facts_in_dir).with("oneA")
        @facter.expects(:load_facts_in_dir).with("oneB")
        @facter.expects(:load_facts_in_dir).with("twoA")
        @facter.expects(:load_facts_in_dir).with("twoB")

        @facter.load
      end
    end
  end
end
