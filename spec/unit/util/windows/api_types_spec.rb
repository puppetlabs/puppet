# encoding: UTF-8

require 'spec_helper'

describe "FFI::MemoryPointer", :if => Puppet.features.microsoft_windows? do
  # use 2 bad bytes at end so we have even number of bytes / characters
  let(:bad_string) { "hello invalid world".encode(Encoding::UTF_16LE) + "\xDD\xDD".force_encoding(Encoding::UTF_16LE) }
  let(:bad_string_bytes) { bad_string.bytes.to_a }
  let(:a_wide_bytes) { "A".encode(Encoding::UTF_16LE).bytes.to_a }
  let(:b_wide_bytes) { "B".encode(Encoding::UTF_16LE).bytes.to_a }

  context "read_wide_string" do
    let (:string) { "foo_bar" }

    it "should properly roundtrip a given string" do
      FFI::MemoryPointer.from_string_to_wide_string(string) do |ptr|
        expect(ptr.read_wide_string(string.length)).to eq(string)
      end
    end

    it "should return a given string in UTF-8" do
      FFI::MemoryPointer.from_string_to_wide_string(string) do |ptr|
        read_string = ptr.read_wide_string(string.length)
        expect(read_string.encoding).to eq(Encoding::UTF_8)
      end
    end

    it "should raise an error and emit a debug message when receiving a string containing invalid bytes in the destination encoding" do
      Puppet[:log_level] = 'debug'

      expect {
        FFI::MemoryPointer.new(:byte, bad_string_bytes.count) do |ptr|
          # uchar here is synonymous with byte
          ptr.put_array_of_uchar(0, bad_string_bytes)

          ptr.read_wide_string(bad_string.length)
        end
      }.to raise_error(Encoding::InvalidByteSequenceError)

      expect(@logs.last.message).to eq("Unable to convert value #{bad_string.dump} to encoding UTF-8 due to #<Encoding::InvalidByteSequenceError: \"\\xDD\\xDD\" on UTF-16LE>")
    end

    it "should not raise an error when receiving a string containing invalid bytes in the destination encoding, when specifying :invalid => :replace" do
      FFI::MemoryPointer.new(:byte, bad_string_bytes.count) do |ptr|
        # uchar here is synonymous with byte
        ptr.put_array_of_uchar(0, bad_string_bytes)

        read_string = ptr.read_wide_string(bad_string.length, Encoding::UTF_8, false, :invalid => :replace)
        expect(read_string).to eq("hello invalid world\uFFFD")
      end
    end

    it "raises an IndexError if asked to read more characters than there are bytes allocated" do
      expect {
        FFI::MemoryPointer.new(:byte, 1) do |ptr|
          ptr.read_wide_string(1) # 1 wchar = 2 bytes
        end
      }.to raise_error(IndexError, /out of bounds/)
    end

    it "raises an IndexError if asked to read a negative number of characters" do
      expect {
        FFI::MemoryPointer.new(:byte, 1) do |ptr|
          ptr.read_wide_string(-1)
        end
      }.to raise_error(IndexError, /out of bounds/)
    end

    it "returns an empty string if asked to read 0 characters" do
      FFI::MemoryPointer.new(:byte, 1) do |ptr|
        expect(ptr.read_wide_string(0)).to eq("")
      end
    end

    it "returns a substring if asked to read fewer characters than are in the byte array" do
      FFI::MemoryPointer.new(:byte, 4) do |ptr|
        ptr.write_array_of_uint8("AB".encode('UTF-16LE').bytes.to_a)
        expect(ptr.read_wide_string(1)).to eq("A")
      end
    end

    it "preserves wide null characters in the string" do
      FFI::MemoryPointer.new(:byte, 6) do |ptr|
        ptr.write_array_of_uint8(a_wide_bytes + [0, 0] + b_wide_bytes)
        expect(ptr.read_wide_string(3)).to eq("A\x00B")
      end
    end
  end

  context "read_arbitrary_wide_string_up_to" do
    let (:string) { "foo_bar" }
    let (:single_null_string) { string + "\x00" }
    let (:double_null_string) { string + "\x00\x00" }

    it "should read a short single null terminated string" do
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        expect(ptr.read_arbitrary_wide_string_up_to).to eq(string)
      end
    end

    it "should read a short double null terminated string" do
      FFI::MemoryPointer.from_string_to_wide_string(double_null_string) do |ptr|
        expect(ptr.read_arbitrary_wide_string_up_to(512, :double_null)).to eq(string)
      end
    end

    it "detects trailing single null wchar" do
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        expect(ptr).to receive(:read_wide_string).with(string.length, anything, anything, anything).and_call_original

        expect(ptr.read_arbitrary_wide_string_up_to).to eq(string)
      end
    end

    it "detects trailing double null wchar" do
      FFI::MemoryPointer.from_string_to_wide_string(double_null_string) do |ptr|
        expect(ptr).to receive(:read_wide_string).with(string.length, anything, anything, anything).and_call_original

        expect(ptr.read_arbitrary_wide_string_up_to(512, :double_null)).to eq(string)
      end
    end

    it "should raises an IndexError if max_length is negative" do
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        expect {
          ptr.read_arbitrary_wide_string_up_to(-1)
        }.to raise_error(IndexError, /out of bounds/)
      end
    end

    it "should return an empty string when the max_length is 0" do
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        expect(ptr.read_arbitrary_wide_string_up_to(0)).to eq("")
      end
    end

    it "should return a string of max_length characters when specified" do
      FFI::MemoryPointer.from_string_to_wide_string(single_null_string) do |ptr|
        expect(ptr.read_arbitrary_wide_string_up_to(3)).to eq(string[0..2])
      end
    end

    it "should return wide strings in UTF-8" do
      FFI::MemoryPointer.from_string_to_wide_string(string) do |ptr|
        read_string = ptr.read_arbitrary_wide_string_up_to
        expect(read_string.encoding).to eq(Encoding::UTF_8)
      end
    end

    it "should not raise an error when receiving a string containing invalid bytes in the destination encoding, when specifying :invalid => :replace" do
      FFI::MemoryPointer.new(:byte, bad_string_bytes.count) do |ptr|
        # uchar here is synonymous with byte
        ptr.put_array_of_uchar(0, bad_string_bytes)

        read_string = ptr.read_arbitrary_wide_string_up_to(ptr.size / 2, :single_null, :invalid => :replace)
        expect(read_string).to eq("hello invalid world\uFFFD")
      end
    end

    it "should raise an IndexError if there isn't a null terminator" do
      # This only works when using a memory pointer with a known number of cells
      # and size per cell, but not arbitrary Pointers
      FFI::MemoryPointer.new(:wchar, 1) do |ptr|
        ptr.write_array_of_uint8(a_wide_bytes)

        expect {
          ptr.read_arbitrary_wide_string_up_to(42)
        }.to raise_error(IndexError, /out of bounds/)
      end
    end

    it "should raise an IndexError if there isn't a double null terminator" do
      # This only works when using a memory pointer with a known number of cells
      # and size per cell, but not arbitrary Pointers
      FFI::MemoryPointer.new(:wchar, 1) do |ptr|
        ptr.write_array_of_uint8(a_wide_bytes)

        expect {
          ptr.read_arbitrary_wide_string_up_to(42, :double_null)
        }.to raise_error(IndexError, /out of bounds/)
      end
    end
  end
end
