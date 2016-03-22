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
      ENV.should_not be_key('PKG_PATH')
      fullname.should == [source]
    end
  end

  def expect_pkgadd_with_env_and_name(source, &block)
    ENV.should_not be_key('PKG_PATH')

    provider.expects(:pkgadd).with do |fullname|
      ENV.should be_key('PKG_PATH')
      ENV['PKG_PATH'].should == source

      fullname.should == [provider.resource[:name]]
    end
    provider.expects(:execpipe).with(['/bin/pkg_info', '-I', provider.resource[:name]]).yields('')

    yield

    ENV.should_not be_key('PKG_PATH')
  end

  describe 'provider features' do
    it { should be_installable }
    it { should be_install_options }
    it { should be_uninstallable }
    it { should be_uninstall_options }
    it { should be_upgradeable }
    it { should be_versionable }
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
      provider_class.instances.should be_nil
    end

    it "should return the empty set if no packages are listed" do
      provider_class.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(StringIO.new(''))
      provider_class.instances.should be_empty
    end

    it "should return all packages when invoked" do
      fixture = File.read(my_fixture('pkginfo.list'))
      provider_class.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(fixture)
      provider_class.instances.map(&:name).sort.should ==
        %w{bash bzip2 expat gettext libiconv lzo openvpn python vim wget}.sort
    end

    it "should return all flavors if set" do
      fixture = File.read(my_fixture('pkginfo_flavors.list'))
      provider_class.expects(:execpipe).with(%w{/bin/pkg_info -a}).yields(fixture)
      instances = provider_class.instances.map {|p| {:name => p.get(:name),
        :ensure => p.get(:ensure), :flavor => p.get(:flavor)}}
      instances.size.should == 2
      instances[0].should == {:name => 'bash', :ensure => '3.1.17', :flavor => 'static'}
      instances[1].should == {:name => 'vim',  :ensure => '7.0.42', :flavor => 'no_x11'}
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

      provider.resource[:source].should == url
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
      provider.latest.should == '4.2.45'
    end

    it "should recognize a new version" do
      pkginfo_query = 'tcsh-6.18.01p1'
      provider.stubs(:pkginfo).with('-Q', 'tcsh').returns(pkginfo_query)
      provider.latest.should == '6.18.01p1'
    end

    it "should recognize a newer version" do
      provider.stubs(:properties).returns({:ensure => '1.6.8'})
      pkginfo_query = 'tcsh-1.6.10'
      provider.stubs(:pkginfo).with('-Q', 'tcsh').returns(pkginfo_query)
      provider.latest.should == '1.6.10'
    end

    it "should recognize a package that is already the newest" do
      pkginfo_query = 'tcsh-6.18.01p0 (installed)'
      provider.stubs(:pkginfo).with('-Q', 'tcsh').returns(pkginfo_query)
      provider.latest.should == '6.18.01p0'
    end
  end

  context "#get_version" do
    it "should return nil if execution fails" do
      provider.expects(:execpipe).raises(Puppet::ExecutionFailure, 'wawawa')
      provider.get_version.should be_nil
    end

    it "should return the package version if in the output" do
      output = 'bash-3.1.17         GNU Bourne Again Shell'
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I bash}).yields(output)
      provider.get_version.should == '3.1.17'
    end

    it "should return the empty string if the package is not present" do
      provider.resource[:name] = 'zsh'
      provider.expects(:execpipe).with(%w{/bin/pkg_info -I zsh}).yields(StringIO.new(''))
      provider.get_version.should == ''
    end
  end

  context "#query" do
    it "should return the installed version if present" do
      fixture = File.read(my_fixture('pkginfo.detail'))
      provider.expects(:pkginfo).with('bash').returns(fixture)
      provider.query.should == { :ensure => '3.1.17' }
    end

    it "should return nothing if not present" do
      provider.resource[:name] = 'zsh'
      provider.expects(:pkginfo).with('zsh').returns('')
      provider.query.should be_nil
    end
  end

  context "#install_options" do
    it "should return nill by default" do
      provider.install_options.should be_nil
    end

    it "should return install_options when set" do
      provider.resource[:install_options] = ['-n']
      provider.resource[:install_options].should == ['-n']
    end

    it "should return multiple install_options when set" do
      provider.resource[:install_options] = ['-L', '/opt/puppet']
      provider.resource[:install_options].should == ['-L', '/opt/puppet']
    end

    it 'should return install_options when set as hash' do
      provider.resource[:install_options] = { '-Darch' => 'vax' }
      provider.install_options.should == ['-Darch=vax']
    end
  end

  context "#uninstall_options" do
    it "should return nill by default" do
      provider.uninstall_options.should be_nil
    end

    it "should return uninstall_options when set" do
      provider.resource[:uninstall_options] = ['-n']
      provider.resource[:uninstall_options].should == ['-n']
    end

    it "should return multiple uninstall_options when set" do
      provider.resource[:uninstall_options] = ['-q', '-c']
      provider.resource[:uninstall_options].should == ['-q', '-c']
    end

    it 'should return uninstall_options when set as hash' do
      provider.resource[:uninstall_options] = { '-Dbaddepend' => '1' }
      provider.uninstall_options.should == ['-Dbaddepend=1']
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
