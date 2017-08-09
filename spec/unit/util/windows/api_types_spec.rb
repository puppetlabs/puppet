# encoding: UTF-8
#!/usr/bin/env ruby

require 'spec_helper'

describe "FFI::MemoryPointer", :if => Puppet.features.microsoft_windows? do
  # use 2 bad bytes at end so we have even number of bytes / characters
  let (:bad_string) { "hello invalid world".encode(Encoding::UTF_16LE) + "\xDD\xDD".force_encoding(Encoding::UTF_16LE) }
  let (:bad_string_bytes) { bad_string.bytes.to_a }

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

    it "should raise an error and emit a debug message when receiving a string containing invalid bytes in the destination encoding" do
      # enable a debug output sink to local string array
      Puppet.debug = true
      arraydest = []
      Puppet::Util::Log.newdestination(Puppet::Test::LogCollector.new(arraydest))

      read_string = nil

      expect {
        FFI::MemoryPointer.new(:byte, bad_string_bytes.count) do |ptr|
          # uchar here is synonymous with byte
          ptr.put_array_of_uchar(0, bad_string_bytes)

          read_string = ptr.read_wide_string(bad_string.length)
        end
      }.to raise_error(Encoding::InvalidByteSequenceError)

      expect(read_string).to be_nil
      expect(arraydest.last.message).to eq("Unable to convert value #{bad_string.dump} to encoding UTF-8 due to #<Encoding::InvalidByteSequenceError: \"\\xDD\\xDD\" on UTF-16LE>")
    end

    it "should not raise an error when receiving a string containing invalid bytes in the destination encoding, when specifying :invalid => :replace" do
      read_string = nil

      FFI::MemoryPointer.new(:byte, bad_string_bytes.count) do |ptr|
        # uchar here is synonymous with byte
        ptr.put_array_of_uchar(0, bad_string_bytes)

        read_string = ptr.read_wide_string(bad_string.length, Encoding::UTF_8, :invalid => :replace)
      end

      expect(read_string).to eq("hello invalid world\uFFFD")
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

    it "should not raise an error when receiving a string containing invalid bytes in the destination encoding, when specifying :invalid => :replace" do
      read_string = nil

      FFI::MemoryPointer.new(:byte, bad_string_bytes.count) do |ptr|
        # uchar here is synonymous with byte
        ptr.put_array_of_uchar(0, bad_string_bytes)

        read_string = ptr.read_arbitrary_wide_string_up_to(ptr.size / 2, :single_null, :invalid => :replace)
      end

      expect(read_string).to eq("hello invalid world\uFFFD")
    end
  end
end
