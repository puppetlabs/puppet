require 'puppet/gettext/config'
require 'spec_helper'

describe Puppet::GettextConfig do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  let(:local_path) do
    local_path ||= Puppet::GettextConfig::LOCAL_PATH
  end

  let(:windows_path) do
    windows_path ||= Puppet::GettextConfig::WINDOWS_PATH
  end

  let(:posix_path) do
    windows_path ||= Puppet::GettextConfig::POSIX_PATH
  end

  describe 'translation mode selection' do
    it 'should select PO mode when given a local config path' do
      expect(Puppet::GettextConfig.translation_mode(local_path)).to eq(:po)
    end

    it 'should select PO mode when given a non-package config path' do
      expect(Puppet::GettextConfig.translation_mode('../fake/path')).to eq(:po)
    end

    it 'should select MO mode when given a Windows package config path' do
      expect(Puppet::GettextConfig.translation_mode(windows_path)).to eq(:mo)
    end

    it 'should select MO mode when given a POSIX package config path' do
      expect(Puppet::GettextConfig.translation_mode(posix_path)).to eq(:mo)
    end
  end

  describe 'loading translations' do
    context 'when given a nil config path' do
      it 'should return false' do
        expect(Puppet::GettextConfig.load_translations('puppet', nil, :po)).to be false
      end
    end

    context 'when given a valid config file location' do
      it 'should return true' do
        expect(Puppet::GettextConfig.load_translations('puppet', local_path, :po)).to be true
      end
    end

    context 'when given a bad file format' do
      it 'should raise an exception' do
        expect { Puppet::GettextConfig.load_translations('puppet', local_path, :bad_format) }.to raise_error(Puppet::Error)
      end
    end
  end
end
