# Note: This unit test depends on having a sample SELinux policy file
# in the same directory as this test called selmodule-example.pp
# with version 1.5.0.  The provided selmodule-example.pp is the first
# 256 bytes taken from /usr/share/selinux/targeted/nagios.pp on Fedora 9

require 'spec_helper'
require 'stringio'

describe Puppet::Type.type(:selmodule).provider(:semodule) do
  let(:resource) { instance_double('resource', name: name) }
  let(:provider) { described_class.new(resource) }

  before :each do
    allow(resource).to receive(:[]).and_return name
  end

  def loaded_modules
    {
      'bar'  => '1.2.3',
      'foo'  => '4.4.4',
      'bang' => '1.0.0',
    }
  end

  def semodule_list_output
    loaded_modules.map{|k,v| "#{k}\t#{v}"}.join("\n")
  end

  describe 'selmodules_loaded' do
    let(:name) { 'foo' }

    it 'should return raise an exception when running selmodule raises an exception' do
      provider.class.loaded_modules = nil # Reset loaded_modules before test
      allow(provider.class).to receive(:command).with(:semodule).and_return '/usr/sbin/semodule'
      allow(provider.class).to receive(:execpipe).with('/usr/sbin/semodule --list')
        .and_yield(StringIO.new("this is\nan error")).and_raise(Puppet::ExecutionFailure, 'it failed')
      expect { provider.selmodules_loaded }
        .to raise_error(Puppet::Error, /Could not list policy modules: ".*" failed with "this is an error"/)
    end

    it 'should return empty hash if no modules are loaded' do
      provider.class.loaded_modules = nil # Reset loaded_modules before test
      allow(provider.class).to receive(:command).with(:semodule).and_return '/usr/sbin/semodule'
      allow(provider.class).to receive(:execpipe).with('/usr/sbin/semodule --list').and_yield StringIO.new('')
      expect(provider.selmodules_loaded).to eq(Hash.new())
    end

    it 'should return hash of loaded modules' do
      provider.class.loaded_modules = nil # Reset loaded_modules before test
      allow(provider.class).to receive(:command).with(:semodule).and_return '/usr/sbin/semodule'
      allow(provider.class).to receive(:execpipe).with('/usr/sbin/semodule --list').and_yield StringIO.new(semodule_list_output)
      expect(provider.selmodules_loaded).to eq(loaded_modules)
    end

    it 'should return cached hash of loaded modules' do
      allow(provider.class).to receive(:loaded_modules).and_return loaded_modules
      allow(provider.class).to receive(:command).with(:semodule).and_return '/usr/sbin/semodule'
      allow(provider.class).to receive(:execpipe).with('/usr/sbin/semodule --list').and_yield StringIO.new("test\t1.0.0")
      expect(provider.selmodules_loaded).to eq(loaded_modules)
    end

    it 'should return cached hash of loaded modules and not raise an exception' do
      allow(provider.class).to receive(:loaded_modules).and_return loaded_modules
      allow(provider.class).to receive(:command).with(:semodule).and_return '/usr/sbin/semodule'
      allow(provider.class).to receive(:execpipe).with('/usr/sbin/semodule --list')
        .and_yield(StringIO.new('this should not be called')).and_raise(Puppet::ExecutionFailure, 'it failed')
      expect(provider.selmodules_loaded).to eq(loaded_modules)
    end
  end

  describe 'exists? method' do
    context 'with name foo' do
      let(:name) { 'foo' }

      it 'should return false if no modules are loaded' do
        allow(provider).to receive(:selmodules_loaded).and_return Hash.new()
        expect(provider.exists?).to eq(false)
      end

      it 'should find a module if it is already loaded' do
        allow(provider).to receive(:selmodules_loaded).and_return loaded_modules
        expect(provider.exists?).to eq(true)
      end
    end

    context 'with name foobar' do
      let(:name) { 'foobar' }

      it 'should return false if not loaded' do
        allow(provider).to receive(:selmodules_loaded).and_return loaded_modules
        expect(provider.exists?).to eq(false)
      end
    end

    context 'with name myfoo' do
      let(:name) { 'myfoo' }

      it 'should return false if module with same suffix is loaded' do
        allow(provider).to receive(:selmodules_loaded).and_return loaded_modules
        expect(provider.exists?).to eq(false)
      end
    end
  end

  describe 'selmodversion_file' do
    let(:name) { 'foo' }

    it 'should return 1.5.0 for the example policy file' do
      allow(provider).to receive(:selmod_name_to_filename).and_return "#{File.dirname(__FILE__)}/selmodule-example.pp"
      expect(provider.selmodversion_file).to eq('1.5.0')
    end
  end

  describe 'syncversion' do
    let(:name) { 'foo' }

    it 'should return :true if loaded and file modules are in sync' do
      allow(provider).to receive(:selmodversion_loaded).and_return '1.5.0'
      allow(provider).to receive(:selmodversion_file).and_return '1.5.0'
      expect(provider.syncversion).to eq(:true)
    end

    it 'should return :false if loaded and file modules are not in sync' do
      allow(provider).to receive(:selmodversion_loaded).and_return '1.4.0'
      allow(provider).to receive(:selmodversion_file).and_return '1.5.0'
      expect(provider.syncversion).to eq(:false)
    end

    it 'should return before checking file version if no loaded policy' do
      allow(provider).to receive(:selmodversion_loaded).and_return nil
      expect(provider.syncversion).to eq(:false)
    end
  end

  describe 'selmodversion_loaded' do
    context 'with name foo' do
      let(:name) { 'foo' }

      it 'should return the version of a loaded module' do
        allow(provider).to receive(:selmodules_loaded).and_return loaded_modules
        expect(provider.selmodversion_loaded).to eq('4.4.4')
      end
    end

    context 'with name foobar' do
      let(:name) { 'foobar' }

      it 'should return nil if module is not loaded' do
        allow(provider).to receive(:selmodules_loaded).and_return loaded_modules
        expect(provider.selmodversion_loaded).to be_nil
      end
    end
  end
end
