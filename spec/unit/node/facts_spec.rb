#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet/node/facts'
require 'matchers/json'

describe Puppet::Node::Facts, "when indirecting" do
  include JSONMatchers

  before do
    @facts = Puppet::Node::Facts.new("me")
  end

  describe "adding local facts" do
    it "should add the node's certificate name as the 'clientcert' fact" do
      @facts.add_local_facts
      expect(@facts.values["clientcert"]).to eq(Puppet.settings[:certname])
    end

    it "adds the Puppet version as a 'clientversion' fact" do
      @facts.add_local_facts
      expect(@facts.values["clientversion"]).to eq(Puppet.version.to_s)
    end

    it "adds the agent side noop setting as 'clientnoop'" do
      @facts.add_local_facts
      expect(@facts.values["clientnoop"]).to eq(Puppet.settings[:noop])
    end

    it "doesn't add the current environment" do
      @facts.add_local_facts
      expect(@facts.values).not_to include("environment")
    end

    it "doesn't replace any existing environment fact when adding local facts" do
      @facts.values["environment"] = "foo"
      @facts.add_local_facts
      expect(@facts.values["environment"]).to eq("foo")
    end
  end

  describe "when sanitizing facts" do
    it "should convert fact values if needed" do
      @facts.values["test"] = /foo/
      @facts.sanitize
      expect(@facts.values["test"]).to eq("(?-mix:foo)")
    end

    it "should convert hash keys if needed" do
      @facts.values["test"] = {/foo/ => "bar"}
      @facts.sanitize
      expect(@facts.values["test"]).to eq({"(?-mix:foo)" => "bar"})
    end

    it "should convert hash values if needed" do
      @facts.values["test"] = {"foo" => /bar/}
      @facts.sanitize
      expect(@facts.values["test"]).to eq({"foo" => "(?-mix:bar)"})
    end

    it "should convert array elements if needed" do
      @facts.values["test"] = [1, "foo", /bar/]
      @facts.sanitize
      expect(@facts.values["test"]).to eq([1, "foo", "(?-mix:bar)"])
    end

    it "should handle nested arrays" do
      @facts.values["test"] = [1, "foo", [/bar/]]
      @facts.sanitize
      expect(@facts.values["test"]).to eq([1, "foo", ["(?-mix:bar)"]])
    end

    it "should handle nested hashes" do
      @facts.values["test"] = {/foo/ => {"bar" => /baz/}}
      @facts.sanitize
      expect(@facts.values["test"]).to eq({"(?-mix:foo)" => {"bar" => "(?-mix:baz)"}})
    end

    it "should handle nester arrays and hashes" do
      @facts.values["test"] = {/foo/ => ["bar", /baz/]}
      @facts.sanitize
      expect(@facts.values["test"]).to eq({"(?-mix:foo)" => ["bar", "(?-mix:baz)"]})
    end
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
        expect(Puppet::Node::Facts.indirection.terminus_class).to eq(:yaml)
      end
    end

    describe "when the Puppet application is not 'master'" do
      it "should default to the 'facter' terminus" do
        pending "Cannot test the behavior of defaults in defaults.rb"
        expect(Puppet::Node::Facts.indirection.terminus_class).to eq(:facter)
      end
    end

  end

  describe "when storing and retrieving" do
    it "doesn't manufacture a `_timestamp` fact value" do
      values = {"one" => "two", "three" => "four"}
      facts = Puppet::Node::Facts.new("mynode", values)

      expect(facts.values).to eq(values)
    end

    describe "when deserializing from yaml" do
      let(:timestamp)  { Time.parse("Thu Oct 28 11:16:31 -0700 2010") }
      let(:expiration) { Time.parse("Thu Oct 28 11:21:31 -0700 2010") }

      def create_facts(values = {})
        Puppet::Node::Facts.new('mynode', values)
      end

      def deserialize_yaml_facts(facts)
        format = Puppet::Network::FormatHandler.format('yaml')
        format.intern(Puppet::Node::Facts, facts.to_yaml)
      end

      it 'preserves `_timestamp` value' do
        facts = deserialize_yaml_facts(create_facts('_timestamp' => timestamp))

        expect(facts.timestamp).to eq(timestamp)
      end

      it "doesn't preserve the `_timestamp` fact" do
        facts = deserialize_yaml_facts(create_facts('_timestamp' => timestamp))

        expect(facts.values['_timestamp']).to be_nil
      end

      it 'preserves expiration time if present' do
        old_facts = create_facts
        old_facts.expiration = expiration
        facts = deserialize_yaml_facts(old_facts)

        expect(facts.expiration).to eq(expiration)
      end

      it 'ignores expiration time if absent' do
        facts = deserialize_yaml_facts(create_facts)

        expect(facts.expiration).to be_nil
      end
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
        expect(facts.name).to eq('foo')
        expect(facts.expiration).to eq(@expiration)
        expect(facts.timestamp).to eq(@timestamp)
        expect(facts.values).to eq({'a' => '1', 'b' => '2', 'c' => '3'})
      end

      it "should generate properly formatted pson" do
        Time.stubs(:now).returns(@timestamp)
        facts = Puppet::Node::Facts.new("foo", {'a' => 1, 'b' => 2, 'c' => 3})
        facts.expiration = @expiration
        result = PSON.parse(facts.to_pson)
        expect(result['name']).to eq(facts.name)
        expect(result['values']).to eq(facts.values)
        expect(result['timestamp']).to eq(facts.timestamp.iso8601(9))
        expect(result['expiration']).to eq(facts.expiration.iso8601(9))
      end

      it "should generate valid facts data against the facts schema" do
        Time.stubs(:now).returns(@timestamp)
        facts = Puppet::Node::Facts.new("foo", {'a' => 1, 'b' => 2, 'c' => 3})
        facts.expiration = @expiration

        expect(facts.to_pson).to validate_against('api/schemas/facts.json')
      end

      it "should not include nil values" do
        facts = Puppet::Node::Facts.new("foo", {'a' => 1, 'b' => 2, 'c' => 3})
        pson = PSON.parse(facts.to_pson)
        expect(pson).not_to be_include("expiration")
      end

      it "should be able to handle nil values" do
        pson = %Q({"name": "foo", "values": {"a": "1", "b": "2", "c": "3"}})
        format = Puppet::Network::FormatHandler.format('pson')
        facts = format.intern(Puppet::Node::Facts,pson)
        expect(facts.name).to eq('foo')
        expect(facts.expiration).to be_nil
      end
    end
  end
end
