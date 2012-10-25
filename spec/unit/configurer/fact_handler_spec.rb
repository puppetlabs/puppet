#! /usr/bin/env ruby
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

    it "should fail if finding facts fails" do
      Puppet[:trace] = false
      Puppet[:certname] = "myhost"
      Puppet::Node::Facts.indirection.expects(:find).raises RuntimeError

      lambda { @facthandler.find_facts }.should raise_error(Puppet::Error)
    end
  end

  it "should only load fact plugins once" do
    Puppet::Node::Facts.indirection.expects(:find).once
    @facthandler.find_facts
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
end
