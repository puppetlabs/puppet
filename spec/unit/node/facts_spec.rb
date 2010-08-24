#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/facts'

describe Puppet::Node::Facts, "when indirecting" do
  before do
    @facts = Puppet::Node::Facts.new("me")
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

      # We have to clear the cache so that the facts ask for our indirection stub,
      # instead of anything that might be cached.
      Puppet::Util::Cacher.expire

      @facts = Puppet::Node::Facts.new("me", "one" => "two")
    end

    it "should redirect to the specified fact store for retrieval" do
      Puppet::Node::Facts.stubs(:indirection).returns(@indirection)
      @indirection.expects(:find)
      Puppet::Node::Facts.find(:my_facts)
    end

    it "should redirect to the specified fact store for storage" do
      Puppet::Node::Facts.stubs(:indirection).returns(@indirection)
      @indirection.expects(:save)
      @facts.save
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
  end
end
