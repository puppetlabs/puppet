#!/usr/bin/env rspec
require 'spec_helper'
require 'matchers/json'
require 'puppet/node/facts'

describe Puppet::Node::Facts, "when indirecting" do
  before do
    @facts = Puppet::Node::Facts.new("me")
  end

  it "should use array indexer methods for interacting with values" do
    @facts["foobar"] = "yayness"
    @facts["foobar"].should == "yayness"
    @facts.values["foobar"].should == "yayness"
  end

  describe "when using the class-level indexer methods" do
    before do
      # Force the cache to clear
      Puppet::Node::Facts.load
    end

    it "should use a Facts instance found via the certname" do
      Puppet[:certname] = "fooness"
      Puppet::Node::Facts.indirection.expects(:find).with("fooness").returns({})
      Puppet::Node::Facts["hostname"]
    end

    it "should return the asked for value from any found facts" do
      facts = Puppet::Node::Facts.indirection.find(Puppet[:certname])
      Puppet::Node::Facts["hostname"].should == facts["hostname"]
    end

    it "should return nil when facts cannot be found" do
      Puppet::Node::Facts.indirection.expects(:find).returns(nil)
      Puppet::Node::Facts["hostname"].should be_nil
    end

    it "should cache the facts between calls" do
      Puppet::Node::Facts["hostname"]
      Puppet::Node::Facts.indirection.expects(:find).never
      Puppet::Node::Facts["hostname"]
    end

    it "should clear the cache when the facts are reloaded" do
      Puppet::Node::Facts["hostname"]
      Puppet::Node::Facts.load
      Puppet::Node::Facts.indirection.expects(:find).returns({})
      Puppet::Node::Facts["hostname"]
    end
  end

  describe "when asked to load" do
    it "should do nothing if there is no terminus configured" do
      Puppet::Node::Facts.indirection.expects(:terminus).returns nil
      lambda { Puppet::Node::Facts.load }.should_not raise_error
    end

    it "should do nothing if its terminus does not support loading" do
      terminus = "non_loading_plugin"
      Puppet::Node::Facts.indirection.expects(:terminus).returns terminus
      lambda { Puppet::Node::Facts.load }.should_not raise_error
    end

    it "should call 'load' on its terminus if one is available and supports the 'load' method" do
      terminus = Puppet::Node::Facts::Facter.new
      terminus.expects(:load)
      Puppet::Node::Facts.indirection.expects(:terminus).returns terminus
      Puppet::Node::Facts.load
    end
  end

  it "should be able to convert all fact values to strings" do
    @facts.values["one"] = 1
    @facts.stringify
    @facts.values["one"].should == "1"
  end

  it "should add the node's certificate name as the 'clientcert' fact when adding local facts" do
    @facts.add_local_facts
    @facts.values["clientcert"].should == Puppet.settings[:certname]
  end

  it "should add the Puppet version as a 'clientversion' fact when adding local facts" do
    @facts.add_local_facts
    @facts.values["clientversion"].should == Puppet.version.to_s
  end

  it "should add the current environment as a fact if one is not set when adding local facts" do
    @facts.add_local_facts
    @facts.values["environment"].should == Puppet[:environment]
  end

  it "should not replace any existing environment fact when adding local facts" do
    @facts.values["environment"] = "foo"
    @facts.add_local_facts
    @facts.values["environment"].should == "foo"
  end

  it "should be able to downcase fact values" do
    Puppet.settings.stubs(:value).returns "eh"
    Puppet.settings.expects(:value).with(:downcasefacts).returns true

    @facts.values["one"] = "Two"

    @facts.downcase_if_necessary
    @facts.values["one"].should == "two"
  end

  it "should only try to downcase strings" do
    Puppet.settings.stubs(:value).returns "eh"
    Puppet.settings.expects(:value).with(:downcasefacts).returns true

    @facts.values["now"] = Time.now

    @facts.downcase_if_necessary
    @facts.values["now"].should be_instance_of(Time)
  end

  it "should not downcase facts if not configured to do so" do
    Puppet.settings.stubs(:value).returns "eh"
    Puppet.settings.expects(:value).with(:downcasefacts).returns false

    @facts.values["one"] = "Two"
    @facts.downcase_if_necessary
    @facts.values["one"].should == "Two"
  end

  describe "when indirecting" do
    before do
      @indirection = stub 'indirection', :request => mock('request'), :name => :facts

      @facts = Puppet::Node::Facts.new("me", "one" => "two")
    end

    it "should redirect to the specified fact store for storage" do
      Puppet::Node::Facts.stubs(:indirection).returns(@indirection)
      @indirection.expects(:save)
      Puppet::Node::Facts.indirection.save(@facts)
    end

    describe "when the Puppet application is 'master'" do
      it "should default to the 'yaml' terminus" do
        pending "Cannot test the behavior of defaults in defaults.rb"
        # Puppet::Node::Facts.indirection.terminus_class.should == :yaml
      end
    end

    describe "when the Puppet application is not 'master'" do
      it "should default to the 'facter' terminus" do
        pending "Cannot test the behavior of defaults in defaults.rb"
        # Puppet::Node::Facts.indirection.terminus_class.should == :facter
      end
    end

  end

  describe "when storing and retrieving" do
    it "should add metadata to the facts" do
      facts = Puppet::Node::Facts.new("me", "one" => "two", "three" => "four")
      facts.values[:_timestamp].should be_instance_of(Time)
    end

    describe "using pson" do
      before :each do
        @timestamp = Time.parse("Thu Oct 28 11:16:31 -0700 2010")
        @expiration = Time.parse("Thu Oct 28 11:21:31 -0700 2010")
      end

      it "should accept properly formatted pson" do
        pson = %Q({"name": "foo", "expiration": "#{@expiration}", "timestamp": "#{@timestamp}", "values": {"a": "1", "b": "2", "c": "3"}})
        format = Puppet::Network::FormatHandler.format('pson')
        facts = format.intern(Puppet::Node::Facts,pson)
        facts.name.should == 'foo'
        facts.expiration.should == @expiration
        facts.values.should == {'a' => '1', 'b' => '2', 'c' => '3', :_timestamp => @timestamp}
      end

      it "should generate properly formatted pson" do
        Time.stubs(:now).returns(@timestamp)
        facts = Puppet::Node::Facts.new("foo", {'a' => 1, 'b' => 2, 'c' => 3})
        facts.expiration = @expiration
        result = PSON.parse(facts.to_pson)
        result['name'].should == facts.name
        result['values'].should == facts.values.reject { |key, value| key.to_s =~ /_/ }
        result['timestamp'].should == facts.timestamp.to_s
        result['expiration'].should == facts.expiration.to_s
      end

      it "should not include nil values" do
        facts = Puppet::Node::Facts.new("foo", {'a' => 1, 'b' => 2, 'c' => 3})
        pson = PSON.parse(facts.to_pson)
        pson.should_not be_include("expiration")
      end

      it "should be able to handle nil values" do
        pson = %Q({"name": "foo", "values": {"a": "1", "b": "2", "c": "3"}})
        format = Puppet::Network::FormatHandler.format('pson')
        facts = format.intern(Puppet::Node::Facts,pson)
        facts.name.should == 'foo'
        facts.expiration.should be_nil
      end
    end
  end
end
