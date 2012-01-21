#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/facts/facter'

describe Puppet::Node::Facts::Facter do
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

  describe "when reloading Facter" do
    before do
      @facter_class = Puppet::Node::Facts::Facter
      Facter.stubs(:clear)
      Facter.stubs(:load)
      Facter.stubs(:loadfacts)
    end

    it "should clear Facter" do
      Facter.expects(:clear)
      @facter_class.reload_facter
    end

    it "should load all Facter facts" do
      Facter.expects(:loadfacts)
      @facter_class.reload_facter
    end
  end
end

describe Puppet::Node::Facts::Facter do
  before :each do
    Puppet::Node::Facts::Facter.stubs(:reload_facter)
    @facter = Puppet::Node::Facts::Facter.new
    Facter.stubs(:to_hash).returns({})
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe Puppet::Node::Facts::Facter, " when finding facts" do
    it "should reset and load facts" do
      clear = sequence 'clear'
      Puppet::Node::Facts::Facter.expects(:reload_facter).in_sequence(clear)
      Puppet::Node::Facts::Facter.expects(:load_fact_plugins).in_sequence(clear)
      @facter.find(@request)
    end

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

  describe Puppet::Node::Facts::Facter, " when saving facts" do

    it "should fail" do
      proc { @facter.save(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  describe Puppet::Node::Facts::Facter, " when destroying facts" do

    it "should fail" do
      proc { @facter.destroy(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  it "should skip files when asked to load a directory" do
    FileTest.expects(:directory?).with("myfile").returns false

    Puppet::Node::Facts::Facter.load_facts_in_dir("myfile")
  end

  it "should load each ruby file when asked to load a directory" do
    FileTest.expects(:directory?).with("mydir").returns true
    Dir.expects(:chdir).with("mydir").yields

    Dir.expects(:glob).with("*.rb").returns %w{a.rb b.rb}

    Puppet::Node::Facts::Facter.expects(:load).with("a.rb")
    Puppet::Node::Facts::Facter.expects(:load).with("b.rb")

    Puppet::Node::Facts::Facter.load_facts_in_dir("mydir")
  end

  describe Puppet::Node::Facts::Facter, "when loading fact plugins from disk" do
    it "should load each directory in the Fact path" do
      Puppet.settings.stubs(:value).returns "foo"
      Puppet.settings.expects(:value).with(:factpath).returns("one#{File::PATH_SEPARATOR}two")

      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("one")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("two")

      Puppet::Node::Facts::Facter.load_fact_plugins
    end

    it "should load all facts from the modules" do
      Puppet.settings.stubs(:value).returns "foo"
      Puppet::Node::Facts::Facter.stubs(:load_facts_in_dir)

      Puppet.settings.expects(:value).with(:modulepath).returns("one#{File::PATH_SEPARATOR}two")

      Dir.stubs(:glob).returns []
      Dir.expects(:glob).with("one/*/lib/facter").returns %w{oneA oneB}
      Dir.expects(:glob).with("two/*/lib/facter").returns %w{twoA twoB}

      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("oneA")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("oneB")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("twoA")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("twoB")

      Puppet::Node::Facts::Facter.load_fact_plugins
    end
  end
end
