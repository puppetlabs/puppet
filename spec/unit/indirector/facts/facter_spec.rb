#! /usr/bin/env ruby
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
    @environment = stub 'environment'
    @request.stubs(:environment).returns(@environment)
    @request.environment.stubs(:modules).returns([])
  end

  describe Puppet::Node::Facts::Facter, " when finding facts" do
    it "should reset and load facts" do
      clear = sequence 'clear'
      Puppet::Node::Facts::Facter.expects(:reload_facter).in_sequence(clear)
      Puppet::Node::Facts::Facter.expects(:load_fact_plugins).in_sequence(clear)
      @facter.find(@request)
    end

    it "should include external facts when feature is present" do
      clear = sequence 'clear'
      Puppet.features.stubs(:external_facts?).returns(:true)
      Puppet::Node::Facts::Facter.expects(:setup_external_facts).in_sequence(clear)
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

    it "should convert facts into strings when stringify_facts is true" do
      Puppet[:stringify_facts] = true
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:stringify)

      @facter.find(@request)
    end

    it "should sanitize facts when stringify_facts is false" do
      Puppet[:stringify_facts] = false
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:sanitize)

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

  it "should include pluginfactdest when loading external facts", :unless => Puppet.features.microsoft_windows? do
    Puppet[:pluginfactdest] = "/plugin/dest"
    File.stubs(:directory?).returns true
    Facter::Util::Config.expects(:external_facts_dirs=).with(includes("/plugin/dest"))
    Puppet::Node::Facts::Facter.setup_external_facts(@request)
  end

  it "should include pluginfactdest when loading external facts", :if => Puppet.features.microsoft_windows? do
    Puppet[:pluginfactdest] = "/plugin/dest"
    File.stubs(:directory?).returns true
    Facter::Util::Config.expects(:external_facts_dirs=).with(includes("C:/plugin/dest"))
    Puppet::Node::Facts::Facter.setup_external_facts(@request)
  end

  describe "when loading fact plugins from disk" do
    let(:one) { File.expand_path("one") }
    let(:two) { File.expand_path("two") }

    it "should load each directory in the Fact path" do
      Puppet[:factpath] = [one, two].join(File::PATH_SEPARATOR)

      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with(one)
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with(two)

      Puppet::Node::Facts::Facter.load_fact_plugins
    end

    it "should load all facts from the modules" do
      Puppet::Node::Facts::Facter.stubs(:load_facts_in_dir)

      Puppet[:modulepath] = [one, two].join(File::PATH_SEPARATOR)

      Dir.stubs(:glob).returns []
      Dir.expects(:glob).with("#{one}/*/lib/facter").returns %w{oneA oneB}
      Dir.expects(:glob).with("#{two}/*/lib/facter").returns %w{twoA twoB}

      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("oneA")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("oneB")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("twoA")
      Puppet::Node::Facts::Facter.expects(:load_facts_in_dir).with("twoB")

      Puppet::Node::Facts::Facter.load_fact_plugins
    end
    it "should include module plugin facts when present" do
      mod = Puppet::Module.new("mymodule", "#{one}/mymodule", @request.environment)
      @request.environment.stubs(:modules).returns([mod])
      File.stubs(:directory?).returns true
      Facter::Util::Config.expects(:external_facts_dirs=).with(includes("#{one}/mymodule/facts.d"))
      Puppet::Node::Facts::Facter.setup_external_facts(@request)
    end
  end
end
