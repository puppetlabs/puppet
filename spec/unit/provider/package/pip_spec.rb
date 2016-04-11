#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:pip)
osfamilies = { ['All', nil] => ['pip', 'pip-python'] }

describe provider_class do

  before do
    @resource = Puppet::Resource.new(:package, "fake_package")
    @provider = provider_class.new(@resource)
    @client = stub_everything('client')
    @client.stubs(:call).with('package_releases', 'real_package').returns(["1.3", "1.2.5", "1.2.4"])
    @client.stubs(:call).with('package_releases', 'fake_package').returns([])
  end

  describe "parse" do

    it "should return a hash on valid input" do
      expect(provider_class.parse("real_package==1.2.5")).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })
    end

    it "should return nil on invalid input" do
      expect(provider_class.parse("foo")).to eq(nil)
    end

  end

  describe "cmd" do
    it "should return pip-python on legacy systems" do
      Facter.stubs(:value).with(:osfamily).returns("legacy")
      expect(provider_class.cmd[1]).to eq('pip-python')
    end

    it "should return pip by default" do
      Facter.stubs(:value).with(:osfamily).returns("All")
      expect(provider_class.cmd[0]).to eq('pip')
    end

  end

  describe "instances" do

    osfamilies.each do |osfamily, pip_cmds|
      it "should return an array on #{osfamily} when #{pip_cmds.join(' or ')} is present" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        pip_cmds.each do |pip_cmd|
          pip_cmds.each do |cmd|
            unless cmd == pip_cmd
              provider_class.expects(:which).with(cmd).returns(nil)
            end
          end
          provider_class.stubs(:pip_version).returns('8.0.1')
          provider_class.expects(:which).with(pip_cmd).returns("/fake/bin/#{pip_cmd}")
          p = stub("process")
          p.expects(:collect).yields("real_package==1.2.5")
          provider_class.expects(:execpipe).with("/fake/bin/#{pip_cmd} freeze").yields(p)
          provider_class.instances
        end
      end

      it "should return an empty array on #{osfamily} when #{pip_cmds.join(' and ')} are missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        pip_cmds.each do |cmd|
          provider_class.expects(:which).with(cmd).returns nil
        end
        expect(provider_class.instances).to eq([])
      end
    end

  end

  describe "query" do

    before do
      @resource[:name] = "real_package"
    end

    it "should return a hash when pip and the package are present" do
      provider_class.expects(:instances).returns [provider_class.new({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })]

      expect(@provider.query).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })
    end

    it "should return nil when the package is missing" do
      provider_class.expects(:instances).returns []
      expect(@provider.query).to eq(nil)
    end

    it "should be case insensitive" do
      @resource[:name] = "Real_Package"

      provider_class.expects(:instances).returns [provider_class.new({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })]

      expect(@provider.query).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })
    end

  end

  describe "latest" do
    context "with pip version < 1.5.4" do
      before :each do
        provider_class.stubs(:pip_version).returns('1.0.1')
        provider_class.stubs(:which).with('pip').returns("/fake/bin/pip")
        provider_class.stubs(:which).with('pip-python').returns("/fake/bin/pip")
      end

      it "should find a version number for new_pip_package" do
        p = StringIO.new(
          <<-EOS
          Downloading/unpacking fake-package
            Using version 0.10.1 (newest of versions: 0.10.1, 0.10, 0.9, 0.8.1, 0.8, 0.7.2, 0.7.1, 0.7, 0.6.1, 0.6, 0.5.2, 0.5.1, 0.5, 0.4, 0.3.1, 0.3, 0.2, 0.1)
            Downloading real-package-0.10.1.tar.gz (544Kb): 544Kb downloaded
          Saved ./foo/real-package-0.10.1.tar.gz
          Successfully downloaded real-package
          EOS
        )
        Puppet::Util::Execution.expects(:execpipe).yields(p).once
        @resource[:name] = "real_package"
        expect(@provider.latest).to eq('0.10.1')
      end

      it "should not find a version number for fake_package" do
        p = StringIO.new(
          <<-EOS
          Downloading/unpacking fake-package
            Could not fetch URL http://pypi.python.org/simple/fake_package: HTTP Error 404: Not Found
            Will skip URL http://pypi.python.org/simple/fake_package when looking for download links for fake-package
            Could not fetch URL http://pypi.python.org/simple/fake_package/: HTTP Error 404: Not Found
            Will skip URL http://pypi.python.org/simple/fake_package/ when looking for download links for fake-package
            Could not find any downloads that satisfy the requirement fake-package
          No distributions at all found for fake-package
          Exception information:
          Traceback (most recent call last):
            File "/usr/lib/python2.7/dist-packages/pip/basecommand.py", line 126, in main
              self.run(options, args)
            File "/usr/lib/python2.7/dist-packages/pip/commands/install.py", line 223, in run
              requirement_set.prepare_files(finder, force_root_egg_info=self.bundle, bundle=self.bundle)
            File "/usr/lib/python2.7/dist-packages/pip/req.py", line 948, in prepare_files
              url = finder.find_requirement(req_to_install, upgrade=self.upgrade)
            File "/usr/lib/python2.7/dist-packages/pip/index.py", line 152, in find_requirement
              raise DistributionNotFound('No distributions at all found for %s' % req)
          DistributionNotFound: No distributions at all found for fake-package

          Storing complete log in /root/.pip/pip.log
          EOS
        )
        Puppet::Util::Execution.expects(:execpipe).yields(p).once
        @resource[:name] = "fake_package"
        expect(@provider.latest).to eq(nil)
      end
    end

    context "with pip version >= 1.5.4" do
      # For Pip 1.5.4 and above, you can get a version list from CLI - which allows for native pip behavior
      # with regards to custom repositories, proxies and the like

      before :each do
        provider_class.stubs(:pip_version).returns('1.5.4')
        provider_class.stubs(:which).with('pip').returns("/fake/bin/pip")
        provider_class.stubs(:which).with('pip-python').returns("/fake/bin/pip")
      end

      it "should find a version number for real_package" do
        p = StringIO.new(
          <<-EOS
          Collecting real-package==versionplease
            Could not find a version that satisfies the requirement real-package==versionplease (from versions: 1.1.3, 1.2, 1.9b1)
          No matching distribution found for real-package==versionplease
          EOS
        )
        Puppet::Util::Execution.expects(:execpipe).with(["/fake/bin/pip", "install", "real_package==versionplease"]).yields(p).once
        @resource[:name] = "real_package"
        latest = @provider.latest
        expect(latest).to eq('1.9b1')
      end

      it "should not find a version number for fake_package" do
        p = StringIO.new(
          <<-EOS
          Collecting fake-package==versionplease
            Could not find a version that satisfies the requirement fake-package==versionplease (from versions: )
          No matching distribution found for fake-package==versionplease
          EOS
        )
        Puppet::Util::Execution.expects(:execpipe).with(["/fake/bin/pip", "install", "fake_package==versionplease"]).yields(p).once
        @resource[:name] = "fake_package"
        expect(@provider.latest).to eq(nil)
      end
    end

  end

  describe "install" do

    before do
      @resource[:name] = "fake_package"
      @url = "git+https://example.com/fake_package.git"
    end

    it "should install" do
      @resource[:ensure] = :installed
      @resource[:source] = nil
      @provider.expects(:lazy_pip).
        with("install", '-q', "fake_package")
      @provider.install
    end

    it "omits the -e flag (GH-1256)" do
      # The -e flag makes the provider non-idempotent
      @resource[:ensure] = :installed
      @resource[:source] = @url
      @provider.expects(:lazy_pip).with() do |*args|
        not args.include?("-e")
      end
      @provider.install
    end

    it "should install from SCM" do
      @resource[:ensure] = :installed
      @resource[:source] = @url
      @provider.expects(:lazy_pip).
        with("install", '-q', "#{@url}#egg=fake_package")
      @provider.install
    end

    it "should install a particular SCM revision" do
      @resource[:ensure] = "0123456"
      @resource[:source] = @url
      @provider.expects(:lazy_pip).
        with("install", "-q", "#{@url}@0123456#egg=fake_package")
      @provider.install
    end

    it "should install a particular version" do
      @resource[:ensure] = "0.0.0"
      @resource[:source] = nil
      @provider.expects(:lazy_pip).with("install", "-q", "fake_package==0.0.0")
      @provider.install
    end

    it "should upgrade" do
      @resource[:ensure] = :latest
      @resource[:source] = nil
      @provider.expects(:lazy_pip).
        with("install", "-q", "--upgrade", "fake_package")
      @provider.install
    end

    it "should handle install options" do
      @resource[:ensure] = :installed
      @resource[:source] = nil
      @resource[:install_options] = [{"--timeout" => "10"}, "--no-index"]
      @provider.expects(:lazy_pip).
        with("install", "-q", "--timeout=10", "--no-index", "fake_package")
      @provider.install
    end

  end

  describe "uninstall" do

    it "should uninstall" do
      @resource[:name] = "fake_package"
      @provider.expects(:lazy_pip).
        with('uninstall', '-y', '-q', 'fake_package')
      @provider.uninstall
    end

  end

  describe "update" do

    it "should just call install" do
      @provider.expects(:install).returns(nil)
      @provider.update
    end

  end

  describe "pip_version" do

    it "should return nil on missing pip" do
      provider_class.stubs(:pip_cmd).returns(nil)
      expect(provider_class.pip_version).to eq(nil)
    end

    it "should look up version if pip is present" do
      provider_class.stubs(:pip_cmd).returns('/fake/bin/pip')
      p = stub("process")
      p.expects(:collect).yields('pip 8.0.2 from /usr/local/lib/python2.7/dist-packages (python 2.7)')
      provider_class.expects(:execpipe).with(['/fake/bin/pip', '--version']).yields(p)
      expect(provider_class.pip_version).to eq('8.0.2')
    end

  end

  describe "lazy_pip" do

    after(:each) do
      Puppet::Type::Package::ProviderPip.instance_variable_set(:@confine_collection, nil)
    end

    it "should succeed if pip is present" do
      @provider.stubs(:pip).returns(nil)
      @provider.method(:lazy_pip).call "freeze"
    end

    osfamilies.each do |osfamily, pip_cmds|
      pip_cmds.each do |pip_cmd|
        it "should retry on #{osfamily} if #{pip_cmd} has not yet been found" do
          Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
          Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
          @provider.expects(:pip).twice.with('freeze').raises(NoMethodError).then.returns(nil)
          pip_cmds.each do |cmd|
            unless cmd == pip_cmd
              @provider.expects(:which).with(cmd).returns(nil)
            end
          end
          @provider.expects(:which).with(pip_cmd).returns("/fake/bin/#{pip_cmd}")
          @provider.method(:lazy_pip).call "freeze"
        end
      end

      it "should fail on #{osfamily} if #{pip_cmds.join(' and ')} are missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        @provider.expects(:pip).with('freeze').raises(NoMethodError)
        pip_cmds.each do |pip_cmd|
          @provider.expects(:which).with(pip_cmd).returns(nil)
        end
        expect { @provider.method(:lazy_pip).call("freeze") }.to raise_error(NoMethodError)
      end

      it "should output a useful error message on #{osfamily} if #{pip_cmds.join(' and ')} are missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        @provider.expects(:pip).with('freeze').raises(NoMethodError)
        pip_cmds.each do |pip_cmd|
          @provider.expects(:which).with(pip_cmd).returns(nil)
        end
        expect { @provider.method(:lazy_pip).call("freeze") }.
          to raise_error(NoMethodError, "Could not locate command #{pip_cmds.join(' and ')}.")
      end

    end

  end

end
