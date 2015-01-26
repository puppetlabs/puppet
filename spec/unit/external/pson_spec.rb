#! /usr/bin/env ruby
# Encoding: UTF-8
require 'spec_helper'

require 'puppet/external/pson/common'

describe PSON do
  {
    'foo' => '"foo"',
    1 => '1',
    "\x80" => "\"\x80\"",
    [] => '[]'
  }.each do |str, expect|
    it "should be able to encode #{str.inspect}" do
      got = str.to_pson
      if got.respond_to? :force_encoding
        expect(got.force_encoding('binary')).to eq(expect.force_encoding('binary'))
      else
        expect(got).to eq(expect)
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

    expect(parsed).to eq(bin_string)
  end

  it "should be able to handle UTF8 that isn't a real unicode character" do
    s = ["\355\274\267"]
    expect(PSON.parse( [s].to_pson )).to eq([s])
  end

  it "should be able to handle UTF8 for \\xFF" do
    s = ["\xc3\xbf"]
    expect(PSON.parse( [s].to_pson )).to eq([s])
  end

  it "should be able to handle invalid UTF8 bytes" do
    s = ["\xc3\xc3"]
    expect(PSON.parse( [s].to_pson )).to eq([s])
  end

  it "should be able to parse JSON containing UTF-8 characters in strings" do
    s = '{ "foö": "bár" }'
    expect { PSON.parse s }.not_to raise_error
  end

  it 'ignores "document_type" during parsing' do
    text = '{"data":{},"document_type":"Node"}'

    expect(PSON.parse(text)).to eq({"data" => {}, "document_type" => "Node"})
  end
end
