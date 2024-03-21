require 'spec_helper'
require 'stringio'

describe Puppet::Type.type(:package).provider(:openbsd) do
  let(:package) { Puppet::Type.type(:package).new(:name => 'bash', :provider => 'openbsd') }
  let(:provider) { described_class.new(package) }

  def expect_read_from_pkgconf(lines)
    pkgconf = double(:readlines => lines)
    expect(Puppet::FileSystem).to receive(:exist?).with('/etc/pkg.conf').and_return(true)
    expect(File).to receive(:open).with('/etc/pkg.conf', 'rb').and_return(pkgconf)
  end

  def expect_pkgadd_with_source(source)
    expect(provider).to receive(:pkgadd).with([source]) do
      expect(ENV).not_to have_key('PKG_PATH')
    end
  end

  def expect_pkgadd_with_env_and_name(source, &block)
    expect(ENV).not_to have_key('PKG_PATH')

    expect(provider).to receive(:pkgadd).with([provider.resource[:name]]) do
      expect(ENV).to have_key('PKG_PATH')
      expect(ENV['PKG_PATH']).to eq(source)
    end
    expect(provider).to receive(:execpipe).with(['/bin/pkg_info', '-I', provider.resource[:name]]).and_yield('')

    yield

    expect(ENV).not_to be_key('PKG_PATH')
  end

  context 'provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_uninstall_options }
    it { is_expected.to be_upgradeable }
    it { is_expected.to be_versionable }
  end

  before :each do
    # Stub some provider methods to avoid needing the actual software
    # installed, so we can test on whatever platform we want.
    allow(described_class).to receive(:command).with(:pkginfo).and_return('/bin/pkg_info')
    allow(described_class).to receive(:command).with(:pkgadd).and_return('/bin/pkg_add')
    allow(described_class).to receive(:command).with(:pkgdelete).and_return('/bin/pkg_delete')

    allow(Puppet::FileSystem).to receive(:exist?)
  end

  context "#instances" do
    it "should return nil if execution failed" do
      expect(described_class).to receive(:execpipe).and_raise(Puppet::ExecutionFailure, 'wawawa')
      expect(described_class.instances).to be_nil
    end

    it "should return the empty set if no packages are listed" do
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a}).and_yield(StringIO.new(''))
      expect(described_class.instances).to be_empty
    end

    it "should return all packages when invoked" do
      fixture = File.read(my_fixture('pkginfo.list'))
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a}).and_yield(fixture)
      expect(described_class.instances.map(&:name).sort).to eq(
        %w{bash bzip2 expat gettext libiconv lzo openvpn python vim wget}.sort
      )
    end

    it "should return all flavors if set" do
      fixture = File.read(my_fixture('pkginfo_flavors.list'))
      expect(described_class).to receive(:execpipe).with(%w{/bin/pkg_info -a}).and_yield(fixture)
      instances = described_class.instances.map {|p| {:name => p.get(:name),
        :ensure => p.get(:ensure), :flavor => p.get(:flavor)}}
      expect(instances.size).to eq(2)
      expect(instances[0]).to eq({:name => 'bash', :ensure => '3.1.17', :flavor => 'static'})
      expect(instances[1]).to eq({:name => 'vim',  :ensure => '7.0.42', :flavor => 'no_x11'})
    end
  end

  context "#install" do
    it 'should use install_options as Array' do
      provider.resource[:install_options] = ['-z']
      expect(provider).to receive(:pkgadd).with(['-r', '-z', 'bash--'])
      provider.install
    end
  end

  context "#latest"  do
    before do
      provider.resource[:source] = '/tmp/tcsh.tgz'
      provider.resource[:name] = 'tcsh'
      allow(provider).to receive(:pkginfo).with('tcsh--')
    end

    it "should return the ensure value if the package is already installed" do
      allow(provider).to receive(:properties).and_return({:ensure => '4.2.45'})
      allow(provider).to receive(:pkginfo).with('-Q', 'tcsh--')
      expect(provider.latest).to eq('4.2.45')
    end

    it "should recognize a new version" do
      pkginfo_query = 'tcsh-6.18.01p1'
      allow(provider).to receive(:pkginfo).with('-Q', 'tcsh').and_return(pkginfo_query)
      expect(provider.latest).to eq('6.18.01p1')
    end

    it "should recognize a newer version" do
      allow(provider).to receive(:properties).and_return({:ensure => '1.6.8'})
      pkginfo_query = 'tcsh-1.6.10'
      allow(provider).to receive(:pkginfo).with('-Q', 'tcsh').and_return(pkginfo_query)
      expect(provider.latest).to eq('1.6.10')
    end

    it "should recognize a package that is already the newest" do
      pkginfo_query = 'tcsh-6.18.01p0 (installed)'
      allow(provider).to receive(:pkginfo).with('-Q', 'tcsh').and_return(pkginfo_query)
      expect(provider.latest).to eq('6.18.01p0')
    end
  end

  context "#get_full_name" do
    it "should return the full unversioned package name when updating with a flavor" do
      provider.resource[:ensure] = 'latest'
      provider.resource[:flavor] = 'static'
      expect(provider.get_full_name).to eq('bash--static')
    end

    it "should return the full unversioned package name when updating without a flavor" do
        provider.resource[:name] = 'puppet'
        provider.resource[:ensure] = 'latest'
        expect(provider.get_full_name).to eq('puppet')
    end

    it "should use the ensure parameter if it is numeric" do
      provider.resource[:name] = 'zsh'
      provider.resource[:ensure] = '1.0'
      expect(provider.get_full_name).to eq('zsh-1.0')
    end

    it "should lookup the correct version" do
      output = 'bash-3.1.17         GNU Bourne Again Shell'
      expect(provider).to receive(:execpipe).with(%w{/bin/pkg_info -I bash}).and_yield(output)
      expect(provider.get_full_name).to eq('bash-3.1.17')
    end

    it "should lookup the correction version with flavors" do
      provider.resource[:name] = 'fossil'
      provider.resource[:flavor] = 'static'
      output = 'fossil-1.29v0-static simple distributed software configuration management'
      expect(provider).to receive(:execpipe).with(%w{/bin/pkg_info -I fossil}).and_yield(output)
      expect(provider.get_full_name).to eq('fossil-1.29v0-static')
    end
  end

  context "#get_version" do
    it "should return nil if execution fails" do
      expect(provider).to receive(:execpipe).and_raise(Puppet::ExecutionFailure, 'wawawa')
      expect(provider.get_version).to be_nil
    end

    it "should return the package version if in the output" do
      output = 'bash-3.1.17         GNU Bourne Again Shell'
      expect(provider).to receive(:execpipe).with(%w{/bin/pkg_info -I bash}).and_yield(output)
      expect(provider.get_version).to eq('3.1.17')
    end

    it "should return the empty string if the package is not present" do
      provider.resource[:name] = 'zsh'
      expect(provider).to receive(:execpipe).with(%w{/bin/pkg_info -I zsh}).and_yield(StringIO.new(''))
      expect(provider.get_version).to eq('')
    end
  end

  context "#query" do
    it "should return the installed version if present" do
      fixture = File.read(my_fixture('pkginfo.detail'))
      expect(provider).to receive(:pkginfo).with('bash').and_return(fixture)
      expect(provider.query).to eq({ :ensure => '3.1.17' })
    end

    it "should return nothing if not present" do
      provider.resource[:name] = 'zsh'
      expect(provider).to receive(:pkginfo).with('zsh').and_return('')
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
    it "should return nill by default" do
      expect(provider.uninstall_options).to be_nil
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
        expect(provider).to receive(:pkgdelete).with('-c', '-q', 'bash')
        provider.purge
      end
    end

    describe 'with uninstall_options' do
      it 'should use uninstall_options as Array' do
        provider.resource[:uninstall_options] = ['-q', '-c']
        expect(provider).to receive(:pkgdelete).with(['-q', '-c'], 'bash')
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

    it 'should remove and install the new flavor if different' do
      provider.resource[:flavor] = 'no_x11-ruby'
      expect(provider).to receive(:uninstall).ordered
      expect(provider).to receive(:install).ordered
      provider.flavor = provider.resource[:flavor]
    end
  end
end
