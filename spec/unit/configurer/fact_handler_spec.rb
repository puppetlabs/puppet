#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/fact_handler'

class FactHandlerTester
  include Puppet::Configurer::FactHandler
end

describe Puppet::Configurer::FactHandler do
  before do
    @facthandler = FactHandlerTester.new
  end

  it "should download fact plugins when :factsync is true" do
    Puppet.settings.expects(:value).with(:factsync).returns true
    @facthandler.should be_download_fact_plugins
  end

  it "should not download fact plugins when :factsync is false" do
    Puppet.settings.expects(:value).with(:factsync).returns false
    @facthandler.should_not be_download_fact_plugins
  end

  it "should not download fact plugins when downloading is disabled" do
    Puppet::Configurer::Downloader.expects(:new).never
    @facthandler.expects(:download_fact_plugins?).returns false
    @facthandler.download_fact_plugins
  end

  it "should use an Agent Downloader, with the name, source, destination, and ignore set correctly, to download fact plugins when downloading is enabled" do
    downloader = mock 'downloader'

    Puppet.settings.expects(:value).with(:factsource).returns "fsource"
    Puppet.settings.expects(:value).with(:factdest).returns "fdest"
    Puppet.settings.expects(:value).with(:factsignore).returns "fignore"

    Puppet::Configurer::Downloader.expects(:new).with("fact", "fdest", "fsource", "fignore").returns downloader

    downloader.expects(:evaluate)

    @facthandler.expects(:download_fact_plugins?).returns true
    @facthandler.download_fact_plugins
  end

  describe "when finding facts" do
    before :each do
      @facthandler.stubs(:reload_facter)
      Puppet::Node::Facts.indirection.terminus_class = :memory
    end

    it "should use the node name value to retrieve the facts" do
      foo_facts = Puppet::Node::Facts.new('foo')
      bar_facts = Puppet::Node::Facts.new('bar')
      Puppet::Node::Facts.indirection.save(foo_facts)
      Puppet::Node::Facts.indirection.save(bar_facts)
      Puppet[:certname] = 'foo'
      Puppet[:node_name_value] = 'bar'

      @facthandler.find_facts.should == bar_facts
    end

    it "should set the facts name based on the node_name_fact" do
      facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
      Puppet::Node::Facts.indirection.save(facts)
      Puppet[:node_name_fact] = 'my_name_fact'

      @facthandler.find_facts.name.should == 'other_node_name'
    end

    it "should set the node_name_value based on the node_name_fact" do
      facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
      Puppet::Node::Facts.indirection.save(facts)
      Puppet[:node_name_fact] = 'my_name_fact'

      @facthandler.find_facts

      Puppet[:node_name_value].should == 'other_node_name'
    end

    it "should reload Facter before finding facts" do
      @facthandler.expects(:reload_facter)

      @facthandler.find_facts
    end

    it "should fail if finding facts fails" do
      Puppet[:trace] = false
      Puppet[:certname] = "myhost"
      Puppet::Node::Facts.indirection.expects(:find).raises RuntimeError

      lambda { @facthandler.find_facts }.should raise_error(Puppet::Error)
    end
  end

  it "should warn about factsync deprecation when factsync is enabled" do
    Puppet::Configurer::Downloader.stubs(:new).returns mock("downloader", :evaluate => nil)

    @facthandler.expects(:download_fact_plugins?).returns true
    Puppet.expects(:warning)
    @facthandler.download_fact_plugins
  end

  # I couldn't get marshal to work for this, only yaml, so we hard-code yaml.
  it "should serialize and CGI escape the fact values for uploading" do
    facts = stub 'facts'
    facts.expects(:support_format?).with(:b64_zlib_yaml).returns true
    facts.expects(:render).returns "my text"
    text = CGI.escape("my text")

    @facthandler.expects(:find_facts).returns facts

    @facthandler.facts_for_uploading.should == {:facts_format => :b64_zlib_yaml, :facts => text}
  end

  it "should properly accept facts containing a '+'" do
    facts = stub 'facts'
    facts.expects(:support_format?).with(:b64_zlib_yaml).returns true
    facts.expects(:render).returns "my+text"
    text = "my%2Btext"

    @facthandler.expects(:find_facts).returns facts

    @facthandler.facts_for_uploading.should == {:facts_format => :b64_zlib_yaml, :facts => text}
  end

  it "use compressed yaml as the serialization if zlib is supported" do
    facts = stub 'facts'
    facts.expects(:support_format?).with(:b64_zlib_yaml).returns true
    facts.expects(:render).with(:b64_zlib_yaml).returns "my text"
    text = CGI.escape("my text")

    @facthandler.expects(:find_facts).returns facts

    @facthandler.facts_for_uploading
  end

  it "should use yaml as the serialization if zlib is not supported" do
    facts = stub 'facts'
    facts.expects(:support_format?).with(:b64_zlib_yaml).returns false
    facts.expects(:render).with(:yaml).returns "my text"
    text = CGI.escape("my text")

    @facthandler.expects(:find_facts).returns facts

    @facthandler.facts_for_uploading
  end

  describe "when reloading Facter" do
    before do
      Facter.stubs(:clear)
      Facter.stubs(:load)
      Facter.stubs(:loadfacts)
    end

    it "should clear Facter" do
      Facter.expects(:clear)
      @facthandler.reload_facter
    end

    it "should load all Facter facts" do
      Facter.expects(:loadfacts)
      @facthandler.reload_facter
    end

    it "should use the Facter terminus load all Puppet Fact plugins" do
      Puppet::Node::Facts::Facter.expects(:load_fact_plugins)
      @facthandler.reload_facter
    end
  end
end
