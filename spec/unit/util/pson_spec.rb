#! /usr/bin/env ruby
# Encoding: UTF-8
require 'spec_helper'

require 'puppet/util/pson'

class PsonUtil
  include Puppet::Util::Pson
end

describe Puppet::Util::Pson do
  it "should fail if no data is provided" do
    expect {
      PsonUtil.new.pson_create("type" => "foo")
    }.to raise_error(ArgumentError, /No data provided in pson data/)
  end

  it "should call 'from_data_hash' with the provided data" do
    pson = PsonUtil.new
    pson.expects(:from_data_hash).with("mydata")
    pson.pson_create("type" => "foo", "data" => "mydata")
  end

  {
    'foo' => '"foo"',
    1 => '1',
    "\x80" => "\"\x80\"",
    [] => '[]'
  }.each do |str, expect|
    it "should be able to encode #{str.inspect}" do
      got = str.to_pson
      if got.respond_to? :force_encoding
        got.force_encoding('binary').should == expect.force_encoding('binary')
      else
        got.should == expect
      end
    end
  end

  it "should be able to handle arbitrary binary data" do
    bin_string = (1..20000).collect { |i| ((17*i+13*i*i) % 255).chr }.join
    parsed = PSON.parse(%Q{{ "type": "foo", "data": #{bin_string.to_pson} }})["data"]

    if parsed.respond_to? :force_encoding
      parsed.force_encoding('binary')
      bin_string.force_encoding('binary')
    end

    parsed.should == bin_string
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

  it "should be able to parse JSON containing UTF-8 characters in strings" do
    s = '{ "foö": "bár" }'
    lambda { PSON.parse s }.should_not raise_error
  end
end
