#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:pip3)
osfamilies = { ['All', nil] => ['pip3'] }

describe provider_class do

  before do
    @resource = Puppet::Resource.new(:package, "fake_package")
    @provider = provider_class.new(@resource)
    @client = stub_everything('client')
    @client.stubs(:call).with('package_releases', 'real_package').returns(["1.3", "1.2.5", "1.2.4"])
    @client.stubs(:call).with('package_releases', 'fake_package').returns([])
    XMLRPC::Client.stubs(:new2).returns(@client)
  end

  describe 'provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_upgradeable }
    it { is_expected.to be_versionable }
    it { is_expected.to be_install_options }
  end

  describe "parse" do

    it "should return a hash on valid input" do
      expect(provider_class.parse("real_package==1.2.5")).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip3,
      })
    end

    it "should return nil on invalid input" do
      expect(provider_class.parse("foo")).to eq(nil)
    end

  end

  describe "cmd" do

    it "should return #{osfamilies[['All', nil]][0]} by default" do
      Facter.stubs(:value).with(:osfamily).returns("Not RedHat")
      expect(provider_class.cmd[0]).to eq(osfamilies[['All', nil]][0])
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
            provider_class.expects(:which).with(pip_cmd).returns("/fake/bin/#{pip_cmd}")
            p = stub("process")
            p.expects(:collect).yields("real_package==1.2.5")
            provider_class.expects(:execpipe).with("/fake/bin/#{pip_cmd} freeze").yields(p)
            provider_class.instances
          end
        end

      it "should return an empty array on #{osfamily} when #{pip_cmds.join(' and ')} is missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        pip_cmds.each do |pip_cmd|
          provider_class.expects(:which).with(pip_cmd).returns nil
        end
        expect(provider_class.instances).to eq([])
      end
    end

  end

  describe "query" do

    before do
      @resource[:name] = "real_package"
    end

    it "should return a hash when pip3 and the package are present" do
      provider_class.expects(:instances).returns [provider_class.new({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip3,
      })]

      expect(@provider.query).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip3,
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
        :provider => :pip3,
      })]

      expect(@provider.query).to eq({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip3,
      })
    end

  end

  describe "latest" do

    it "should find a version number for real_package" do
      @resource[:name] = "real_package"
      expect(@provider.latest).not_to eq(nil)
    end

    it "should not find a version number for fake_package" do
      @resource[:name] = "fake_package"
      expect(@provider.latest).to eq(nil)
    end

    it "should handle a timeout gracefully" do
      @resource[:name] = "fake_package"
      @client.stubs(:call).raises(Timeout::Error)
      expect { @provider.latest }.to raise_error(Puppet::Error)
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

  describe "lazy_pip" do

    after(:each) do
      Puppet::Type::Package::ProviderPip.instance_variable_set(:@confine_collection, nil)
    end

    it "should succeed if pip3 is present" do
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

        it "should fail on #{osfamily} if #{pip_cmd} is missing" do
          Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
          Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
          @provider.expects(:pip).with('freeze').raises(NoMethodError)
          pip_cmds.each do |pip_cmd|
            @provider.expects(:which).with(pip_cmd).returns(nil)
          end
          expect { @provider.method(:lazy_pip).call("freeze") }.to raise_error(NoMethodError)
        end

        it "should output a useful error message on #{osfamily} if #{pip_cmd} is missing" do
          Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
          Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
          @provider.expects(:pip).with('freeze').raises(NoMethodError)
          pip_cmds.each do |pip_cmd|
            @provider.expects(:which).with(pip_cmd).returns(nil)
          end
          expect { @provider.method(:lazy_pip).call("freeze") }.
            to raise_error(NoMethodError, "Could not locate command #{pip_cmd}.")
        end
      end
    end

  end

end
