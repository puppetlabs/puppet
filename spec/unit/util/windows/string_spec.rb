# encoding: UTF-8
#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/util/windows'

describe "Puppet::Util::Windows::String", :if => Puppet.features.microsoft_windows? do

  def wide_string(str)
    Puppet::Util::Windows::String.wide_string(str)
  end

  context "wide_string" do
    it "should return encoding of UTF-16LE" do
      wide_string("bob").encoding.should == Encoding::UTF_16LE
    end

    it "should return valid encoding" do
      wide_string("bob").valid_encoding?.should be_true
    end

    it "should convert an ASCII string" do
      string_value = "bob".encode(Encoding::US_ASCII)
      result = wide_string(string_value)
      expected = string_value.encode(Encoding::UTF_16LE)

      result.bytes.to_a.should == expected.bytes.to_a
    end

    it "should convert a UTF-8 string" do
      string_value = "bob".encode(Encoding::UTF_8)
      result = wide_string(string_value)
      expected = string_value.encode(Encoding::UTF_16LE)

      result.bytes.to_a.should == expected.bytes.to_a
    end

    it "should convert a UTF-16LE string" do
      string_value = "bob\u00E8".encode(Encoding::UTF_16LE)
      result = wide_string(string_value)
      expected = string_value.encode(Encoding::UTF_16LE)

      result.bytes.to_a.should == expected.bytes.to_a
    end

    it "should convert a UTF-16BE string" do
      string_value = "bob\u00E8".encode(Encoding::UTF_16BE)
      result = wide_string(string_value)
      expected = string_value.encode(Encoding::UTF_16LE)

      result.bytes.to_a.should == expected.bytes.to_a
    end

    it "should convert an UTF-32LE string" do
      string_value = "bob\u00E8".encode(Encoding::UTF_32LE)
      result = wide_string(string_value)
      expected = string_value.encode(Encoding::UTF_16LE)

      result.bytes.to_a.should == expected.bytes.to_a
    end

    it "should convert an UTF-32BE string" do
      string_value = "bob\u00E8".encode(Encoding::UTF_32BE)
      result = wide_string(string_value)
      expected = string_value.encode(Encoding::UTF_16LE)

      result.bytes.to_a.should == expected.bytes.to_a
    end
  end
end
