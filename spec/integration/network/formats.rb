#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

class JsonIntTest
    attr_accessor :string
    def ==(other)
        other.class == self.class and string == other.string
    end

    def self.from_json(data)
        new(data[0])
    end

    def initialize(string)
        @string = string
    end

    def to_json(*args)
        {
            'json_class' => self.class.name,
            'data' => [@string]
        }.to_json(*args)
    end

    def self.canonical_order(s)
        s.gsub(/\{"data":\[(.*?)\],"json_class":"JsonIntTest"\}/,'{"json_class":"JsonIntTest","data":[\1]}')
    end

end

describe Puppet::Network::FormatHandler.format(:s) do
    before do
        @format = Puppet::Network::FormatHandler.format(:s)
    end

    it "should support certificates" do
        @format.should be_supported(Puppet::SSL::Certificate)
    end

    it "should not support catalogs" do
        @format.should_not be_supported(Puppet::Resource::Catalog)
    end
end

describe Puppet::Network::FormatHandler.format(:json) do
    describe "when json is absent" do
        confine "'json' library is prsent" => (! Puppet.features.json?)

        it "should not be suitable" do
            @json.should_not be_suitable
        end
    end

    describe "when json is available" do
        confine "Missing 'json' library" => Puppet.features.json?

        before do
            @json = Puppet::Network::FormatHandler.format(:json)
        end

        it "should be able to render an instance to json" do
            instance = JsonIntTest.new("foo")
            JsonIntTest.canonical_order(@json.render(instance)).should == JsonIntTest.canonical_order('{"json_class":"JsonIntTest","data":["foo"]}' )
        end

        it "should be able to render arrays to json" do
            @json.render([1,2]).should == '[1,2]'
        end

        it "should be able to render arrays containing hashes to json" do
            @json.render([{"one"=>1},{"two"=>2}]).should == '[{"one":1},{"two":2}]'
        end

        it "should be able to render multiple instances to json" do
            Puppet.features.add(:json, :libs => ["json"])

            one = JsonIntTest.new("one")
            two = JsonIntTest.new("two")

            JsonIntTest.canonical_order(@json.render([one,two])).should == JsonIntTest.canonical_order('[{"json_class":"JsonIntTest","data":["one"]},{"json_class":"JsonIntTest","data":["two"]}]')
        end

        it "should be able to intern json into an instance" do
            @json.intern(JsonIntTest, '{"json_class":"JsonIntTest","data":["foo"]}').should == JsonIntTest.new("foo")
        end

        it "should be able to intern json with no class information into an instance" do
            @json.intern(JsonIntTest, '["foo"]').should == JsonIntTest.new("foo")
        end

        it "should be able to intern multiple instances from json" do
            @json.intern_multiple(JsonIntTest, '[{"json_class": "JsonIntTest", "data": ["one"]},{"json_class": "JsonIntTest", "data": ["two"]}]').should == [
                JsonIntTest.new("one"), JsonIntTest.new("two")
            ]
        end

        it "should be able to intern multiple instances from json with no class information" do
            @json.intern_multiple(JsonIntTest, '[["one"],["two"]]').should == [
                JsonIntTest.new("one"), JsonIntTest.new("two")
            ]
        end
    end
end
