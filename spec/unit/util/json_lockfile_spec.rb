#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/json_lockfile'

describe Puppet::Util::JsonLockfile do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::JsonLockfile.new(@lockfile)

    @original_encoding = Encoding.default_external
    Encoding.default_external = Encoding::ISO_8859_1
  end

  after(:each) do
    Encoding.default_external = @original_encoding
  end

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎

  describe "#lock" do
    it "should create a lock file containing a json hash" do
      data = { "foo" => "foofoo", "bar" => "barbar", mixed_utf8 => mixed_utf8 }
      @lock.lock(data)

      expect(PSON.parse(File.read(@lockfile, :encoding => Encoding::BINARY))).to eq(data)
    end
  end

  describe "reading lock data" do
    it "returns deserialized JSON from the lockfile" do
      data = { "foo" => "foofoo", "bar" => "barbar" }
      @lock.lock(data)
      expect(@lock.lock_data).to eq data
    end

    it "returns nil if the file read returned nil" do
      @lock.lock
      File.stubs(:read).returns nil
      expect(@lock.lock_data).to be_nil
    end

    it "returns nil if the file was empty" do
      @lock.lock
      File.stubs(:read).returns ''
      expect(@lock.lock_data).to be_nil
    end

    it "returns nil if the file was not in PSON" do
      @lock.lock
      File.stubs(:read).returns ']['
      expect(@lock.lock_data).to be_nil
    end

  end
end
