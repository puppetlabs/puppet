#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/pson'

class PsonUtil
  include Puppet::Util::Pson
end

describe Puppet::Util::Pson, :'fails_on_ruby_1.9.2' => true do
  it "should fail if no data is provided" do
    lambda { PsonUtil.new.pson_create("type" => "foo") }.should raise_error(ArgumentError)
  end

  it "should call 'from_pson' with the provided data" do
    pson = PsonUtil.new
    pson.expects(:from_pson).with("mydata")
    pson.pson_create("type" => "foo", "data" => "mydata")
  end


  { 
    'foo' => '"foo"',
    1 => '1',
    "\x80" => "\"\x80\"",
    [] => '[]'
  }.each { |str,pson|
    it "should be able to encode #{str.inspect}" do
      str.to_pson.should == pson
    end
  }

  it "should be able to handle arbitrary binary data" do
    bin_string = (1..20000).collect { |i| ((17*i+13*i*i) % 255).chr }.join
    PSON.parse(%Q{{ "type": "foo", "data": #{bin_string.to_pson} }})["data"].should == bin_string
  end

  it "should be able to handle UTF8 that isn't a real unicode character" do
    s = ["\355\274\267"]
    PSON.parse( [s].to_pson ).should == [s]
  end

  it "should be able to handle UTF8 for \\xFF" do
    s = ["\xc3\xbf"]
    PSON.parse( [s].to_pson ).should == [s]
  end

  it "should be able to handle invalid UTF8 bytes" do
    s = ["\xc3\xc3"]
    PSON.parse( [s].to_pson ).should == [s]
  end
end
