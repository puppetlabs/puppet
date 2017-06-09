#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

if Puppet::Util::Platform.windows?
describe Puppet::Util::Windows::Registry do
  subject do
    class TestRegistry
      include Puppet::Util::Windows::Registry
      extend FFI::Library

      ffi_lib :advapi32
      attach_function :RegSetValueExW,
        [:handle, :pointer, :dword, :dword, :pointer, :dword], :win32_long

      def write_corrupt_dword(reg, valuename)
        # Normally DWORDs contain 4 bytes.  This bad data only has 2
        bad_data = [0, 0]
        FFI::Pointer.from_string_to_wide_string(valuename) do |name_ptr|
          FFI::MemoryPointer.new(:uchar, bad_data.length) do |data_ptr|
            data_ptr.write_array_of_uchar(bad_data)
            if RegSetValueExW(reg.hkey, name_ptr, 0,
              Win32::Registry::REG_DWORD, data_ptr, data_ptr.size) != 0
                raise Puppet::Util::Windows::Error.new("Failed to write registry value")
            end
          end
        end
      end
    end

    TestRegistry.new
  end

  let(:name)   { 'HKEY_LOCAL_MACHINE' }
  let(:path)   { 'Software\Microsoft' }

  context "#root" do
    it "should lookup the root hkey" do
      expect(subject.root(name)).to be_instance_of(Win32::Registry::PredefinedKey)
    end

    it "should raise for unknown root keys" do
      expect { subject.root('HKEY_BOGUS') }.to raise_error(Puppet::Error, /Invalid registry key/)
    end
  end

  context "#open" do
    let(:hkey)   { stub 'hklm' }
    let(:subkey) { stub 'subkey' }

    before :each do
      subject.stubs(:root).returns(hkey)
    end

    it "should yield the opened the subkey" do
      hkey.expects(:open).with do |p, _|
        expect(p).to eq(path)
      end.yields(subkey)

      yielded = nil
      subject.open(name, path) {|reg| yielded = reg}
      expect(yielded).to eq(subkey)
    end

    if Puppet::Util::Platform.windows?
      [described_class::KEY64, described_class::KEY32].each do |access|
        it "should open the key for read access 0x#{access.to_s(16)}" do
          mode = described_class::KEY_READ | access
          hkey.expects(:open).with(path, mode)

          subject.open(name, path, mode) {|reg| }
        end
      end
    end

    it "should default to KEY64" do
      hkey.expects(:open).with(path, described_class::KEY_READ | described_class::KEY64)

      subject.open(hkey, path) {|hkey| }
    end

    it "should raise for a path that doesn't exist" do
      hkey.expects(:keyname).returns('HKEY_LOCAL_MACHINE')
      hkey.expects(:open).raises(Win32::Registry::Error.new(2)) # file not found
      expect do
        subject.open(hkey, 'doesnotexist') {|hkey| }
      end.to raise_error(Puppet::Error, /Failed to open registry key 'HKEY_LOCAL_MACHINE\\doesnotexist'/)
    end
  end

  context "#values" do
    let(:key) { stub('uninstall') }

    def expects_registry_value(array)
      key.expects(:each_value).never
      subject.expects(:each_value).with(key).multiple_yields(array)

      subject.values(key).first[1]
    end

    it "should return each value's name and data" do
      key.expects(:each_value).never
      subject.expects(:each_value).with(key).multiple_yields(
        ['string', 1, 'foo'], ['dword', 4, 0]
      )
      expect(subject.values(key)).to eq({ 'string' => 'foo', 'dword' => 0 })
    end

    it "should return an empty hash if there are no values" do
      key.expects(:each_value).never
      subject.expects(:each_value).with(key)

      expect(subject.values(key)).to eq({})
    end

    it "passes REG_DWORD through" do
      reg_value = ['dword', Win32::Registry::REG_DWORD, '1']

      value = expects_registry_value(reg_value)

      expect(Integer(value)).to eq(1)
    end

    context "when reading non-ASCII values" do
      ENDASH_UTF_8 = [0xE2, 0x80, 0x93]
      ENDASH_UTF_16 = [0x2013]
      TM_UTF_8 = [0xE2, 0x84, 0xA2]
      TM_UTF_16 = [0x2122]

      let (:hklm) { Win32::Registry::HKEY_LOCAL_MACHINE }
      let (:puppet_key) { "SOFTWARE\\Puppet Labs"}
      let (:subkey_name) { "PuppetRegistryTest#{SecureRandom.uuid}" }
      let (:guid) { SecureRandom.uuid }
      let (:regsam) { Puppet::Util::Windows::Registry::KEY32 }

      after(:each) do
        # Ruby 2.1.5 has bugs with deleting registry keys due to using ANSI
        # character APIs, but passing wide strings to them (facepalm)
        # https://github.com/ruby/ruby/blob/v2_1_5/ext/win32/lib/win32/registry.rb#L323-L329
        # therefore, use our own built-in registry helper code

        hklm.open(puppet_key, Win32::Registry::KEY_ALL_ACCESS | regsam) do |reg|
          subject.delete_key(reg, subkey_name, regsam)
        end
      end

      # proof that local encodings (such as IBM437 are no longer relevant)
      it "will return a UTF-8 string from a REG_SZ registry value (written as UTF-16LE)",
        :if => Puppet::Util::Platform.windows? && RUBY_VERSION >= '2.1' do

        # create a UTF-16LE byte array representing "–™"
        utf_16_bytes = ENDASH_UTF_16 + TM_UTF_16
        utf_16_str = utf_16_bytes.pack('s*').force_encoding(Encoding::UTF_16LE)

        # and it's UTF-8 equivalent bytes
        utf_8_bytes = ENDASH_UTF_8 + TM_UTF_8
        utf_8_str = utf_8_bytes.pack('c*').force_encoding(Encoding::UTF_8)

        # this problematic Ruby codepath triggers a conversion of UTF-16LE to
        # a local codepage which can totally break when that codepage has no
        # conversion from the given UTF-16LE characters to local codepage
        # a prime example is that IBM437 has no conversion from a Unicode en-dash
        Win32::Registry.expects(:export_string).never

        # also, expect that we're using our variants of keys / values, not Rubys
        Win32::Registry.expects(:each_key).never
        Win32::Registry.expects(:each_value).never

        hklm.create("#{puppet_key}\\#{subkey_name}", Win32::Registry::KEY_ALL_ACCESS | regsam) do |reg|
          reg.write("#{guid}", Win32::Registry::REG_SZ, utf_16_str)

          # trigger Puppet::Util::Windows::Registry FFI calls
          keys = subject.keys(reg)
          vals = subject.values(reg)

          expect(keys).to be_empty
          expect(vals).to have_key(guid)

          # The UTF-16LE string written should come back as the equivalent UTF-8
          written = vals[guid]
          expect(written).to eq(utf_8_str)
          expect(written.encoding).to eq(Encoding::UTF_8)
        end
      end
    end

    context "when reading values" do
      let (:hklm) { Win32::Registry::HKEY_LOCAL_MACHINE }
      let (:puppet_key) { "SOFTWARE\\Puppet Labs"}
      let (:subkey_name) { "PuppetRegistryTest#{SecureRandom.uuid}" }
      let (:value_name) { SecureRandom.uuid }

      after(:each) do
        hklm.open(puppet_key, Win32::Registry::KEY_ALL_ACCESS) do |reg|
          subject.delete_key(reg, subkey_name)
        end
      end

      [
        {:name => 'REG_SZ', :type => Win32::Registry::REG_SZ, :value => 'reg sz string'},
        {:name => 'REG_EXPAND_SZ', :type => Win32::Registry::REG_EXPAND_SZ, :value => 'reg expand string'},
        {:name => 'REG_MULTI_SZ', :type => Win32::Registry::REG_MULTI_SZ, :value => ['string1', 'string2']},
        {:name => 'REG_BINARY', :type => Win32::Registry::REG_BINARY, :value => 'abinarystring'},
        {:name => 'REG_DWORD', :type => Win32::Registry::REG_DWORD, :value => 0xFFFFFFFF},
        {:name => 'REG_DWORD_BIG_ENDIAN', :type => Win32::Registry::REG_DWORD_BIG_ENDIAN, :value => 0xFFFF},
        {:name => 'REG_QWORD', :type => Win32::Registry::REG_QWORD, :value => 0xFFFFFFFFFFFFFFFF},
      ].each do |pair|
        it "should return #{pair[:name]} values" do
          hklm.create("#{puppet_key}\\#{subkey_name}", Win32::Registry::KEY_ALL_ACCESS) do |reg|
            reg.write(value_name, pair[:type], pair[:value])
          end

          hklm.open("#{puppet_key}\\#{subkey_name}", Win32::Registry::KEY_READ) do |reg|
            vals = subject.values(reg)

            expect(vals).to have_key(value_name)
            subject.each_value(reg) do |subkey, type, data|
              expect(type).to eq(pair[:type])
            end

            written = vals[value_name]
            expect(written).to eq(pair[:value])
          end
        end
      end
    end

    context "when reading corrupt values" do
      let (:hklm) { Win32::Registry::HKEY_LOCAL_MACHINE }
      let (:puppet_key) { "SOFTWARE\\Puppet Labs"}
      let (:subkey_name) { "PuppetRegistryTest#{SecureRandom.uuid}" }
      let (:value_name) { SecureRandom.uuid }

      before(:each) do
        hklm.create("#{puppet_key}\\#{subkey_name}", Win32::Registry::KEY_ALL_ACCESS) do |reg_key|
          subject.write_corrupt_dword(reg_key, value_name)
        end
      end

      after(:each) do
        hklm.open(puppet_key, Win32::Registry::KEY_ALL_ACCESS) do |reg_key|
          subject.delete_key(reg_key, subkey_name)
        end
      end

      it "should return nil for a corrupt DWORD" do
        hklm.open("#{puppet_key}\\#{subkey_name}", Win32::Registry::KEY_ALL_ACCESS) do |reg_key|
          vals = subject.values(reg_key)

          expect(vals).to have_key(value_name)
          expect(vals[value_name]).to be_nil
        end
      end
    end
  end
end
end
