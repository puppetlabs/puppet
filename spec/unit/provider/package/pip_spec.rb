require 'spec_helper'

osfamilies = { 'windows' => ['pip.exe'], 'other' => ['pip', 'pip-python'] }

describe Puppet::Type.type(:package).provider(:pip) do

  it { is_expected.to be_installable }
  it { is_expected.to be_uninstallable }
  it { is_expected.to be_upgradeable }
  it { is_expected.to be_versionable }
  it { is_expected.to be_install_options }
  it { is_expected.to be_targetable }

  before do
    @resource = Puppet::Resource.new(:package, "fake_package")
    allow(@resource).to receive(:original_parameters).and_return({})
    @provider = described_class.new(@resource)
    @client = double('client')
    allow(@client).to receive(:call).with('package_releases', 'real_package').and_return(["1.3", "1.2.5", "1.2.4"])
    allow(@client).to receive(:call).with('package_releases', 'fake_package').and_return([])
  end

  context "parse" do
    it "should return a hash on valid input" do
      expect(described_class.parse("real_package==1.2.5")).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })
    end

    it "should return nil on invalid input" do
      expect(described_class.parse("foo")).to eq(nil)
    end
  end

  context "cmd" do
    it "should return 'pip.exe' by default on Windows systems" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
      expect(described_class.cmd[0]).to eq('pip.exe')
    end

    it "could return pip-python on legacy redhat systems which rename pip" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      expect(described_class.cmd[1]).to eq('pip-python')
    end

    it "should return pip by default on other systems" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      expect(described_class.cmd[0]).to eq('pip')
    end
  end

  context "instances" do
    osfamilies.each do |osfamily, pip_cmds|
      it "should return an array on #{osfamily} systems when #{pip_cmds.join(' or ')} is present" do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(osfamily == 'windows')
        pip_cmds.each do |pip_cmd|
          pip_cmds.each do |cmd|
            unless cmd == pip_cmd
              expect(described_class).to receive(:which).with(cmd).and_return(nil)
            end
          end
          allow(described_class).to receive(:pip_version).with(pip_cmd).and_return('8.0.1')
          expect(described_class).to receive(:which).with(pip_cmd).and_return(pip_cmd)
          p = double("process")
          expect(p).to receive(:collect).and_yield("real_package==1.2.5")
          expect(described_class).to receive(:execpipe).with([pip_cmd, ["freeze"]]).and_yield(p)
          described_class.instances
        end
      end

      context "with pip version >= 8.1.0" do
        versions = ['8.1.0', '9.0.1']
        versions.each do |version|
          it "should use the --all option when version is '#{version}'" do
            allow(Puppet::Util::Platform).to receive(:windows?).and_return(osfamily == 'windows')
            allow(described_class).to receive(:provider_command).and_return('/fake/bin/pip')
            allow(described_class).to receive(:pip_version).with('/fake/bin/pip').and_return(version)
            p = double("process")
            expect(p).to receive(:collect).and_yield("real_package==1.2.5")
            expect(described_class).to receive(:execpipe).with(["/fake/bin/pip", ["freeze", "--all"]]).and_yield(p)
            described_class.instances
          end
        end
      end

      it "should return an empty array on #{osfamily} systems when #{pip_cmds.join(' and ')} are missing" do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(osfamily == 'windows')
        pip_cmds.each do |cmd|
          expect(described_class).to receive(:which).with(cmd).and_return(nil)
        end
        expect(described_class.instances).to eq([])
      end
    end
  end

  context "query" do
    before do
      @resource[:name] = "real_package"
      allow(described_class).to receive(:provider_command).and_return('/fake/bin/pip')
      allow(described_class).to receive(:validate_command).with('/fake/bin/pip')
    end

    it "should return a hash when pip and the package are present" do
      expect(described_class).to receive(:instances).and_return([described_class.new({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
        :command  => '/fake/bin/pip',
      })])

      expect(@provider.query).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
        :command  => '/fake/bin/pip',
      })
    end

    it "should return nil when the package is missing" do
      expect(described_class).to receive(:instances).and_return([])
      expect(@provider.query).to eq(nil)
    end

    it "should be case insensitive" do
      @resource[:name] = "Real_Package"

      expect(described_class).to receive(:instances).and_return([described_class.new({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
        :command  => '/fake/bin/pip',
      })])

      expect(@provider.query).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
        :command  => '/fake/bin/pip',
      })
    end
  end

  context "latest" do
    context "with pip version < 1.5.4" do
      before :each do
        allow(@provider).to receive(:pip_version).with("/fake/bin/pip").and_return('1.0.1')
        allow(described_class).to receive(:which).with('pip').and_return("/fake/bin/pip")
        allow(described_class).to receive(:which).with('pip-python').and_return("/fake/bin/pip")
        allow(described_class).to receive(:which).with('pip.exe').and_return("/fake/bin/pip")
        allow(described_class).to receive(:provider_command).and_return('/fake/bin/pip')
        allow(described_class).to receive(:validate_command).with('/fake/bin/pip')
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
        expect(Puppet::Util::Execution).to receive(:execpipe).and_yield(p).once
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
        expect(Puppet::Util::Execution).to receive(:execpipe).and_yield(p).once
        @resource[:name] = "fake_package"
        expect(@provider.latest).to eq(nil)
      end
    end

    context "with pip version >= 1.5.4" do
      # For Pip 1.5.4 and above, you can get a version list from CLI - which allows for native pip behavior
      # with regards to custom repositories, proxies and the like
      before :each do
        allow(described_class).to receive(:which).with('pip').and_return("/fake/bin/pip")
        allow(described_class).to receive(:which).with('pip-python').and_return("/fake/bin/pip")
        allow(described_class).to receive(:which).with('pip.exe').and_return("/fake/bin/pip")
        allow(described_class).to receive(:provider_command).and_return('/fake/bin/pip')
        allow(described_class).to receive(:validate_command).with('/fake/bin/pip')
        allow(@provider).to receive(:pip_version).with("/fake/bin/pip").and_return('1.5.4')
      end

      it "should find a version number for real_package" do
        p = StringIO.new(
          <<-EOS
          Collecting real-package==versionplease
            Could not find a version that satisfies the requirement real-package==versionplease (from versions: 1.1.3, 1.2, 1.9b1)
          No matching distribution found for real-package==versionplease
          EOS
        )
        expect(Puppet::Util::Execution).to receive(:execpipe).with(["/fake/bin/pip", "install", "real_package==versionplease"]).and_yield(p).once
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
        expect(Puppet::Util::Execution).to receive(:execpipe).with(["/fake/bin/pip", "install", "fake_package==versionplease"]).and_yield(p).once
        @resource[:name] = "fake_package"
        expect(@provider.latest).to eq(nil)
      end

      it "should handle out-of-order version numbers for real_package" do
        p = StringIO.new(
          <<-EOS
          Collecting real-package==versionplease
            Could not find a version that satisfies the requirement real-package==versionplease (from versions: 1.11, 13.0.3, 1.6, 1.9, 1.3.2, 14.0.1, 12.0.7, 13.0.3, 1.7.2, 1.8.4, 1.6.1, 0.9.2, 1.3, 1.8.3, 12.1.1, 1.1, 1.11.6, 1.4.8, 1.6.3, 1.10.1, 14.0.2, 1.11.3, 14.0.3, 1.4rc1, 0.8.4, 1.0, 12.0.5, 14.0.6, 1.11.5, 1.7.1.1, 1.11.4, 13.0.1, 13.1.2, 1.3.3, 0.8.2, 14.0.0, 12.0, 1.8, 1.3.4, 12.0, 1.2, 12.0.6, 0.9.1, 13.1.1, 14.0.5, 15.0.2, 15.0.0, 1.4.5, 1.4.3, 13.1.1, 1.11.2, 13.1.2, 1.3.1, 13.1.0, 12.0.2, 1.11.1, 12.0.1, 12.1.0, 0.9, 1.4.4, 13.0.0, 1.4.9, 12.1.0, 1.7.1, 1.4.2, 14.0.5, 0.8.1, 1.4.6, 0.8.3, 1.11.3, 1.5.1, 1.4.7, 13.0.2, 12.0.7, 13.0.0, 1.9.1, 1.8.2, 14.0.1, 14.0.0, 14.0.4, 1.6.2, 15.0.1, 13.1.0, 0.8, 1.7, 15.0.2, 12.0.5, 13.0.1, 1.8.1, 1.11.6, 15.0.1, 12.0.4, 12.1.1, 13.0.2, 1.11.4, 1.10, 14.0.4, 14.0.6, 1.4.1, 1.4, 1.5.2, 12.0.2, 12.0.1, 14.0.3, 14.0.2, 1.11.1, 1.7.1.2, 15.0.0, 12.0.4, 1.6.4, 1.11.2, 1.5)
          No distributions matching the version for real-package==versionplease
          EOS
        )
        expect(Puppet::Util::Execution).to receive(:execpipe).with(["/fake/bin/pip", "install", "real_package==versionplease"]).and_yield(p).once
        @resource[:name] = "real_package"
        latest = @provider.latest
        expect(latest).to eq('15.0.2')
      end
    end
  end

  context "install" do
    before do
      @resource[:name] = "fake_package"
      @url = "git+https://example.com/fake_package.git"
      allow(described_class).to receive(:provider_command).and_return('/fake/bin/pip')
      allow(described_class).to receive(:validate_command).with('/fake/bin/pip')
    end

    it "should install" do
      @resource[:ensure] = :installed
      @resource[:source] = nil
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["install", "-q", "fake_package"]])
      @provider.install
    end

    it "omits the -e flag (GH-1256)" do
      # The -e flag makes the provider non-idempotent
      @resource[:ensure] = :installed
      @resource[:source] = @url
      # TJK
      expect(@provider).to receive(:execute) do |*args|
        expect(args).not_to include("-e")
      end
      @provider.install
    end

    it "should install from SCM" do
      @resource[:ensure] = :installed
      @resource[:source] = @url
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["install", "-q", "#{@url}#egg=fake_package"]])
      @provider.install
    end

    it "should install a particular SCM revision" do
      @resource[:ensure] = "0123456"
      @resource[:source] = @url
      # TJK
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["install", "-q", "#{@url}@0123456#egg=fake_package"]])
      @provider.install
    end

    it "should install a particular version" do
      @resource[:ensure] = "0.0.0"
      @resource[:source] = nil
      # TJK
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["install", "-q", "fake_package==0.0.0"]])
      @provider.install
    end

    it "should upgrade" do
      @resource[:ensure] = :latest
      @resource[:source] = nil
      # TJK
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["install", "-q", "--upgrade", "fake_package"]])
      @provider.install
    end

    it "should handle install options" do
      @resource[:ensure] = :installed
      @resource[:source] = nil
      @resource[:install_options] = [{"--timeout" => "10"}, "--no-index"]
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["install", "-q", "--timeout=10", "--no-index", "fake_package"]])
      @provider.install
    end
  end

  context "uninstall" do
    before do
      allow(described_class).to receive(:provider_command).and_return('/fake/bin/pip')
      allow(described_class).to receive(:validate_command).with('/fake/bin/pip')
    end

    it "should uninstall" do
      @resource[:name] = "fake_package"
      expect(@provider).to receive(:execute).with(["/fake/bin/pip", ["uninstall", "-y", "-q", "fake_package"]])
      @provider.uninstall
    end
  end

  context "update" do
    it "should just call install" do
      expect(@provider).to receive(:install).and_return(nil)
      @provider.update
    end
  end

  context "pip_version" do
    it "should look up version if pip is present" do
      allow(described_class).to receive(:pip_cmd).and_return('/fake/bin/pip')
      p = double("process")
      expect(p).to receive(:collect).and_yield('pip 8.0.2 from /usr/local/lib/python2.7/dist-packages (python 2.7)')
      expect(described_class).to receive(:execpipe).with(['/fake/bin/pip', '--version']).and_yield(p)
      expect(described_class.pip_version('/fake/bin/pip')).to eq('8.0.2')
    end
  end
end
