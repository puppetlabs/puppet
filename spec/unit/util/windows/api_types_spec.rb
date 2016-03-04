# encoding: UTF-8
#!/usr/bin/env ruby

require 'spec_helper'

describe "FFI::MemoryPointer", :if => Puppet.features.microsoft_windows? do
  context "read_wide_string" do
    let (:string) { "foo_bar" }

    it "should properly roundtrip a given string" do
      read_string = nil
      FFI::MemoryPointer.from_string_to_wide_string(string) do |ptr|
        read_string = ptr.read_wide_string(string.length)
      end

      expect(read_string).to eq(string)
    end

    it "should return a given string in UTF-8" do
      read_string = nil
      FFI::MemoryPointer.from_string_to_wide_string(string) do |ptr|
        read_string = ptr.read_wide_string(string.length)
      end

      expect(read_string.encoding).to eq(Encoding::UTF_8)
    end
  end

  context "read_arbitrary_wide_string_up_to" do
    let (:string) { "foo_bar" }
    let (:single_null_string) { string + "\x00" }
    let (:double_null_string) { string + "\x00\x00" }

    it "should read a short single null terminated string" do
      read_string = nil
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        read_string = ptr.read_arbitrary_wide_string_up_to()
      end

      expect(read_string).to eq(string)
    end

    it "should read a short double null terminated string" do
      read_string = nil
      FFI::MemoryPointer.from_string_to_wide_string(double_null_string) do |ptr|
        read_string = ptr.read_arbitrary_wide_string_up_to(512, :double_null)
      end

      expect(read_string).to eq(string)
    end

    it "should return a string of max_length characters when specified" do
      read_string = nil
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        read_string = ptr.read_arbitrary_wide_string_up_to(3)
      end

      expect(read_string).to eq(string[0..2])
    end

    it "should return wide strings in UTF-8" do
      read_string = nil
      FFI::MemoryPointer.from_string_to_wide_string(string) do |ptr|
        read_string = ptr.read_arbitrary_wide_string_up_to()
      end

      expect(read_string.encoding).to eq(Encoding::UTF_8)
    end
  end
end
