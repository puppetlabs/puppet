require 'spec_helper'
require 'stringio'

describe Puppet::Type.type(:package).provider(:openbsd) do
  include PuppetSpec::Fixtures

  let(:package) { Puppet::Type.type(:package).new(:name => 'bash', :provider => 'openbsd') }
  let(:provider) { described_class.new(package) }

  context 'provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_uninstall_options }
  end

  before :each do
    # Stub some provider methods to avoid needing the actual software
    # installed, so we can test on whatever platform we want.
    allow(described_class).to receive(:command).with(:pkginfo).and_return('/bin/pkg_info')
    allow(described_class).to receive(:command).with(:pkgadd).and_return('/bin/pkg_add')
    allow(described_class).to receive(:command).with(:pkgdelete).and_return('/bin/pkg_delete')
  end

  context "#instances" do
    it "should return nil if execution failed" do
      #expect(provider).to receive(:pkginfo).and_raise(Puppet::ExecutionFailure, 'wawawa')
      #expect(provider).to receive(:pkginfo).with(['-a', '-z'])
      expect(described_class.instances).to be_nil
    end

    it "should return the empty set if no packages are listed" do
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a -z}).and_yield(StringIO.new(''))
      expect(described_class.instances).to be_empty
    end

    it "should return all packages when invoked" do
      fixture = File.read(my_fixture('pkginfo.list'))
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a -z}).and_yield(fixture)
      expect(described_class.instances.map(&:name).sort).to eq(
        %w{autoconf%2.13 autoconf%2.56 bash postfix%stable puppet%8 zstd}.sort
      )
    end

    it "should return all flavors if set" do
      fixture = File.read(my_fixture('pkginfo.list'))
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a -z}).and_yield(fixture)
      instances = described_class.instances.map {|p| {:name => p.get(:name),
        :flavor => p.get(:flavor), :branch => p.get(:branch)}}
      expect(instances.size).to eq(6)
      expect(instances[0]).to eq({:name => 'autoconf%2.13', :flavor => :absent, :branch => '%2.13'})
      expect(instances[1]).to eq({:name => 'autoconf%2.56', :flavor => :absent, :branch => '%2.56'})
      expect(instances[2]).to eq({:name => 'bash', :flavor => :absent, :branch => :absent})
      expect(instances[3]).to eq({:name => 'postfix%stable', :flavor => 'ldap', :branch => '%stable'})
      expect(instances[4]).to eq({:name => 'puppet%8', :flavor => :absent, :branch => '%8'})
      expect(instances[5]).to eq({:name => 'zstd', :flavor => :absent, :branch => :absent})
    end
  end

  context "#install" do
    it 'should use install_options as Array' do
      provider.resource[:install_options] = ['-z']
      expect(provider).to receive(:pkgadd).with(['-r', '-z', 'bash--'])
      provider.install
    end
  end

  context "#get_full_name" do
    it "should return the full unversioned package name when installing with a flavor" do
      provider.resource[:ensure] = 'present'
      provider.resource[:flavor] = 'static'
      expect(provider.get_full_name).to eq('bash--static')
    end

    it "should return the full unversioned package name when installing with a branch" do
      provider.resource[:name] = 'bash%stable'
      expect(provider.get_full_name).to eq('bash--%stable')
    end

    it "should return the full unversioned package name when installing without a flavor" do
        provider.resource[:name] = 'puppet'
        expect(provider.get_full_name).to eq('puppet--')
    end

    it "should return unversioned package name when installing without flavor or branch" do
      expect(provider.get_full_name).to eq('bash--')
    end

    it "should return the full unversioned package name when installing with branch and flavor" do
        provider.resource[:name] = 'postfix%stable'
        provider.resource[:flavor] = 'ldap-mysql'
        expect(provider.get_full_name).to eq('postfix--ldap-mysql%stable')
    end

  end

  context "#query" do
    it "should return package info if present" do
      fixture = File.read(my_fixture('pkginfo.list'))
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a -z}).and_yield(fixture)
      expect(provider.query).to eq({:branch=>nil, :flavor=>nil, :name=>"bash", :provider=>:openbsd})
    end

    it "should return nothing if not present" do
      fixture = File.read(my_fixture('pkginfo.list'))
      provider.resource[:name] = 'zsh'
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a -z}).and_yield(fixture)
      expect(provider.query).to be_nil
    end
  end

  context "#install_options" do
    it "should return nill by default" do
      expect(provider.install_options).to be_nil
    end

    it "should return install_options when set" do
      provider.resource[:install_options] = ['-n']
      expect(provider.resource[:install_options]).to eq(['-n'])
    end

    it "should return multiple install_options when set" do
      provider.resource[:install_options] = ['-L', '/opt/puppet']
      expect(provider.resource[:install_options]).to eq(['-L', '/opt/puppet'])
    end

    it 'should return install_options when set as hash' do
      provider.resource[:install_options] = { '-Darch' => 'vax' }
      expect(provider.install_options).to eq(['-Darch=vax'])
    end
  end

  context "#uninstall_options" do
    it "should return empty array by default" do
      expect(provider.uninstall_options).to eq([])
    end

    it "should return uninstall_options when set" do
      provider.resource[:uninstall_options] = ['-n']
      expect(provider.resource[:uninstall_options]).to eq(['-n'])
    end

    it "should return multiple uninstall_options when set" do
      provider.resource[:uninstall_options] = ['-q', '-c']
      expect(provider.resource[:uninstall_options]).to eq(['-q', '-c'])
    end

    it 'should return uninstall_options when set as hash' do
      provider.resource[:uninstall_options] = { '-Dbaddepend' => '1' }
      expect(provider.uninstall_options).to eq(['-Dbaddepend=1'])
    end
  end

  context "#uninstall" do
    describe 'when uninstalling' do
      it 'should use erase to purge' do
        expect(provider).to receive(:pkgdelete).with('-c', '-qq', [], 'bash--')
        provider.purge
      end
    end

    describe 'with uninstall_options' do
      it 'should use uninstall_options as Array' do
        provider.resource[:uninstall_options] = ['-q', '-c']
        expect(provider).to receive(:pkgdelete).with(['-q', '-c'], 'bash--')
        provider.uninstall
      end
    end
  end

  context "#flavor" do
    before do
      provider.instance_variable_get('@property_hash')[:flavor] = 'no_x11-python'
    end

    it 'should return the existing flavor' do
      expect(provider.flavor).to eq('no_x11-python')
    end

    it 'should reinstall the new flavor if different' do
      provider.resource[:flavor] = 'no_x11-ruby'
      expect(provider).to receive(:install).ordered
      provider.flavor = provider.resource[:flavor]
    end
  end
end
