#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/formats'

class PsonIntTest
  attr_accessor :string
  def ==(other)
    other.class == self.class and string == other.string
  end

  def self.from_data_hash(data)
    new(data[0])
  end

  def initialize(string)
    @string = string
  end

  def to_pson(*args)
    {
      'type' => self.class.name,
      'data' => [@string]
    }.to_pson(*args)
  end

  def self.canonical_order(s)
    s.gsub(/\{"data":\[(.*?)\],"type":"PsonIntTest"\}/,'{"type":"PsonIntTest","data":[\1]}')
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

describe Puppet::Network::FormatHandler.format(:pson) do
  before do
    @pson = Puppet::Network::FormatHandler.format(:pson)
  end

  it "should be able to render an instance to pson" do
    instance = PsonIntTest.new("foo")
    PsonIntTest.canonical_order(@pson.render(instance)).should == PsonIntTest.canonical_order('{"type":"PsonIntTest","data":["foo"]}' )
  end

  it "should be able to render arrays to pson" do
    @pson.render([1,2]).should == '[1,2]'
  end

  it "should be able to render arrays containing hashes to pson" do
    @pson.render([{"one"=>1},{"two"=>2}]).should == '[{"one":1},{"two":2}]'
  end

  it "should be able to render multiple instances to pson" do
    one = PsonIntTest.new("one")
    two = PsonIntTest.new("two")

    PsonIntTest.canonical_order(@pson.render([one,two])).should == PsonIntTest.canonical_order('[{"type":"PsonIntTest","data":["one"]},{"type":"PsonIntTest","data":["two"]}]')
  end

  it "should be able to intern pson into an instance" do
    @pson.intern(PsonIntTest, '{"type":"PsonIntTest","data":["foo"]}').should == PsonIntTest.new("foo")
  end

  it "should be able to intern pson with no class information into an instance" do
    @pson.intern(PsonIntTest, '["foo"]').should == PsonIntTest.new("foo")
  end

  it "should be able to intern multiple instances from pson" do
    @pson.intern_multiple(PsonIntTest, '[{"type": "PsonIntTest", "data": ["one"]},{"type": "PsonIntTest", "data": ["two"]}]').should == [
      PsonIntTest.new("one"), PsonIntTest.new("two")
    ]
  end

  it "should be able to intern multiple instances from pson with no class information" do
    @pson.intern_multiple(PsonIntTest, '[["one"],["two"]]').should == [
      PsonIntTest.new("one"), PsonIntTest.new("two")
    ]
  end
end
