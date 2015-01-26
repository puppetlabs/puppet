#! /usr/bin/env ruby
require 'spec_helper'
require 'stringio'

provider_class = Puppet::Type.type(:package).provider(:openbsd)

describe provider_class do
  let(:package) { Puppet::Type.type(:package).new(:name => 'bash', :provider => 'openbsd') }
  let(:provider) { provider_class.new(package) }

  def expect_read_from_pkgconf(lines)
    pkgconf = stub(:readlines => lines)
    Puppet::FileSystem.expects(:exist?).with('/etc/pkg.conf').returns(true)
    File.expects(:open).with('/etc/pkg.conf', 'rb').returns(pkgconf)
  end

  def expect_pkgadd_with_source(source)
    provider.expects(:pkgadd).with do |fullname|
      expect(ENV).not_to be_key('PKG_PATH')
      expect(fullname).to eq([source])
    end
  end

  def expect_pkgadd_with_env_and_name(source, &block)
    expect(ENV).not_to be_key('PKG_PATH')

    provider.expects(:pkgadd).with do |fullname|
      expect(ENV).to be_key('PKG_PATH')
      expect(ENV['PKG_PATH']).to eq(source)

      expect(fullname).to eq([provider.resource[:name]])
    end
    provider.expects(:execpipe).with(['/bin/pkg_info', '-I', provider.resource[:name]]).yields('')

    yield

    expect(ENV).not_to be_key('PKG_PATH')
  end

  describe 'provider features' do
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
    provider_class.stubs(:command).with(:pkginfo).returns('/bin/pkg_info')
    provider_class.stubs(:command).with(:pkgadd).returns('/bin/pkg_add')
    provider_class.stubs(:command).with(:pkgdelete).returns('/bin/pkg_delete')
  end

  context "#instances" do
    it "should return nil if execution failed" do
      provider_class.expects(:execpipe).raises(Puppet::ExecutionFailure, 'wawawa')
      expect(provider_class.instances).to be_nil
    end

    it "should return the empty set if no packages are listed" do
      provider_class.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(StringIO.new(''))
      expect(provider_class.instances).to be_empty
    end

    it "should return all packages when invoked" do
      fixture = File.read(my_fixture('pkginfo.list'))
      provider_class.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(fixture)
      expect(provider_class.instances.map(&:name).sort).to eq(
        %w{bash bzip2 expat gettext libiconv lzo openvpn python vim wget}.sort
      )
    end

    it "should return all flavors if set" do
      fixture = File.read(my_fixture('pkginfo_flavors.list'))
      provider_class.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(fixture)
      instances = provider_class.instances.map {|p| {:name => p.get(:name),
        :ensure => p.get(:ensure), :flavor => p.get(:flavor)}}
      expect(instances.size).to eq(2)
      expect(instances[0]).to eq({:name => 'bash', :ensure => '3.1.17', :flavor => 'static'})
      expect(instances[1]).to eq({:name => 'vim',  :ensure => '7.0.42', :flavor => 'no_x11'})
    end
  end

  context "#install" do
    it "should fail if the resource doesn't have a source" do
      Puppet::FileSystem.expects(:exist?).with('/etc/pkg.conf').returns(false)

      expect {
        provider.install
      }.to raise_error(Puppet::Error, /must specify a package source/)
    end

    it "should fail if /etc/pkg.conf exists, but is not readable" do
      Puppet::FileSystem.expects(:exist?).with('/etc/pkg.conf').returns(true)
      File.expects(:open).with('/etc/pkg.conf', 'rb').raises(Errno::EACCES)

      expect {
        provider.install
      }.to raise_error(Errno::EACCES, /Permission denied/)
    end

    it "should fail if /etc/pkg.conf exists, but there is no installpath" do
      expect_read_from_pkgconf([])
      expect {
        provider.install
      }.to raise_error(Puppet::Error, /No valid installpath found in \/etc\/pkg\.conf and no source was set/)
    end

    it "should install correctly when given a directory-unlike source" do
      source = '/whatever.tgz'
      provider.resource[:source] = source
      expect_pkgadd_with_source(source)

      provider.install
    end

    it "should install correctly when given a directory-like source" do
      source = '/whatever/'
      provider.resource[:source] = source
      expect_pkgadd_with_env_and_name(source) do
        provider.install
      end
    end

    it "should install correctly when given a CDROM installpath" do
      dir = '/mnt/cdrom/5.2/packages/amd64/'
      expect_read_from_pkgconf(["installpath = #{dir}"])
      expect_pkgadd_with_env_and_name(dir) do
        provider.install
      end
    end

    it "should install correctly when given a ftp mirror" do
      url = 'ftp://your.ftp.mirror/pub/OpenBSD/5.2/packages/amd64/'
      expect_read_from_pkgconf(["installpath = #{url}"])
      expect_pkgadd_with_env_and_name(url) do
        provider.install
      end
    end

    it "should set the resource's source parameter" do
      url = 'ftp://your.ftp.mirror/pub/OpenBSD/5.2/packages/amd64/'
      expect_read_from_pkgconf(["installpath = #{url}"])
      expect_pkgadd_with_env_and_name(url) do
        provider.install
      end

      expect(provider.resource[:source]).to eq(url)
    end

    it "should strip leading whitespace in installpath" do
      dir = '/one/'
      lines = ["# Notice the extra spaces after the ='s\n",
               "installpath =   #{dir}\n",
               "# And notice how each line ends with a newline\n"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_env_and_name(dir) do
        provider.install
      end
    end

    it "should not require spaces around the equals" do
      dir = '/one/'
      lines = ["installpath=#{dir}"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_env_and_name(dir) do
        provider.install
      end
    end

    it "should be case-insensitive" do
      dir = '/one/'
      lines = ["INSTALLPATH = #{dir}"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_env_and_name(dir) do
        provider.install
      end
    end

    it "should ignore unknown keywords" do
      dir = '/one/'
      lines = ["foo = bar\n",
               "installpath = #{dir}\n"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_env_and_name(dir) do
        provider.install
      end
    end

    it "should preserve trailing spaces" do
      dir = '/one/   '
      lines = ["installpath = #{dir}"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_source(dir)

      provider.install
    end

    it "should append installpath" do
      urls = ["ftp://your.ftp.mirror/pub/OpenBSD/5.2/packages/amd64/",
              "http://another.ftp.mirror/pub/OpenBSD/5.2/packages/amd64/"]
      lines = ["installpath  = #{urls[0]}\n",
               "installpath += #{urls[1]}\n"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_env_and_name(urls.join(":")) do
        provider.install
      end
    end

    it "should handle append on first installpath" do
      url = "ftp://your.ftp.mirror/pub/OpenBSD/5.2/packages/amd64/"
      lines = ["installpath += #{url}\n"]

      expect_read_from_pkgconf(lines)
      expect_pkgadd_with_env_and_name(url) do
        provider.install
      end
    end

    %w{ installpath installpath= installpath+=}.each do |line|
      it "should reject '#{line}'" do
        expect_read_from_pkgconf([line])
        expect {
          provider.install
        }.to raise_error(Puppet::Error, /No valid installpath found in \/etc\/pkg\.conf and no source was set/)
      end
    end

    it 'should use install_options as Array' do
      provider.resource[:source] = '/tma1/'
      provider.resource[:install_options] = ['-r', '-z']
      provider.expects(:pkgadd).with(['-r', '-z', 'bash'])
      provider.install
    end
  end

  context "#latest"  do
    before do
      provider.resource[:source] = '/tmp/tcsh.tgz'
      provider.resource[:name] = 'tcsh'
      provider.stubs(:pkginfo).with('tcsh')
    end

    it "should return the ensure value if the package is already installed" do
      provider.stubs(:properties).returns({:ensure => '4.2.45'})
      provider.stubs(:pkginfo).with('-Q', 'tcsh')
      expect(provider.latest).to eq('4.2.45')
    end

    it "should recognize a new version" do
      pkginfo_query = 'tcsh-6.18.01p1'
      provider.stubs(:pkginfo).with('-Q', 'tcsh').returns(pkginfo_query)
      expect(provider.latest).to eq('6.18.01p1')
    end

    it "should recognize a newer version" do
      provider.stubs(:properties).returns({:ensure => '1.6.8'})
      pkginfo_query = 'tcsh-1.6.10'
      provider.stubs(:pkginfo).with('-Q', 'tcsh').returns(pkginfo_query)
      expect(provider.latest).to eq('1.6.10')
    end

    it "should recognize a package that is already the newest" do
      pkginfo_query = 'tcsh-6.18.01p0 (installed)'
      provider.stubs(:pkginfo).with('-Q', 'tcsh').returns(pkginfo_query)
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
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I bash}).yields(output)
      expect(provider.get_full_name).to eq('bash-3.1.17')
    end

    it "should lookup the correction version with flavors" do
      provider.resource[:name] = 'fossil'
      provider.resource[:flavor] = 'static'
      output = 'fossil-1.29v0-static simple distributed software configuration management'
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I fossil}).yields(output)
      expect(provider.get_full_name).to eq('fossil-1.29v0-static')
    end
  end

  context "#get_version" do
    it "should return nil if execution fails" do
      provider.expects(:execpipe).raises(Puppet::ExecutionFailure, 'wawawa')
      expect(provider.get_version).to be_nil
    end

    it "should return the package version if in the output" do
      output = 'bash-3.1.17         GNU Bourne Again Shell'
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I bash}).yields(output)
      expect(provider.get_version).to eq('3.1.17')
    end

    it "should return the empty string if the package is not present" do
      provider.resource[:name] = 'zsh'
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I zsh}).yields(StringIO.new(''))
      expect(provider.get_version).to eq('')
    end
  end

  context "#query" do
    it "should return the installed version if present" do
      fixture = File.read(my_fixture('pkginfo.detail'))
      provider.expects(:pkginfo).with('bash').returns(fixture)
      expect(provider.query).to eq({ :ensure => '3.1.17' })
    end

    it "should return nothing if not present" do
      provider.resource[:name] = 'zsh'
      provider.expects(:pkginfo).with('zsh').returns('')
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
        provider.expects(:pkgdelete).with('-c', '-q', 'bash')
        provider.purge
      end
    end

    describe 'with uninstall_options' do
      it 'should use uninstall_options as Array' do
        provider.resource[:uninstall_options] = ['-q', '-c']
        provider.expects(:pkgdelete).with(['-q', '-c'], 'bash')
        provider.uninstall
      end
    end
  end
end
