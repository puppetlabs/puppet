#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:pip)
osfamilies = { ['RedHat', '6'] => 'pip-python', ['RedHat', '7'] => 'pip', ['Not RedHat', nil] => 'pip' }

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
      provider_class.parse("real_package==1.2.5").should == {
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      }
    end

    it "should return nil on invalid input" do
      provider_class.parse("foo").should == nil
    end

  end

  describe "cmd" do
    it "should return pip-python on RedHat < 7 systems" do
      Facter.stubs(:value).with(:osfamily).returns("RedHat")
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("6")
      provider_class.cmd.should == 'pip-python'
    end

    it "should return pip on RedHat >= 7 systems" do
      Facter.stubs(:value).with(:osfamily).returns("RedHat")
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("7")
      provider_class.cmd.should == 'pip'
    end

    it "should return pip by default" do
      Facter.stubs(:value).with(:osfamily).returns("Not RedHat")
      provider_class.cmd.should == 'pip'
    end

  end

  describe "instances" do

    osfamilies.each do |osfamily, pip_cmd|
      it "should return an array on #{osfamily} when #{pip_cmd} is present" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        provider_class.expects(:which).with(pip_cmd).returns("/fake/bin/pip")
        p = stub("process")
        p.expects(:collect).yields("real_package==1.2.5")
        provider_class.expects(:execpipe).with("/fake/bin/pip freeze").yields(p)
        provider_class.instances
      end

      it "should return an empty array on #{osfamily} when #{pip_cmd} is missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        provider_class.expects(:which).with(pip_cmd).returns nil
        provider_class.instances.should == []
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

      @provider.query.should == {
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      }
    end

    it "should return nil when the package is missing" do
      provider_class.expects(:instances).returns []
      @provider.query.should == nil
    end

    it "should be case insensitive" do
      @resource[:name] = "Real_Package"

      provider_class.expects(:instances).returns [provider_class.new({
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      })]

      @provider.query.should == {
        :ensure   => "1.2.5",
        :name     => "real_package",
        :provider => :pip,
      }
    end

  end

  describe "latest" do
    context "connecting directly" do

      before :each do
        XMLRPC::Client.expects(:new2).with("http://pypi.python.org/pypi", nil).returns(@client)
      end

      it "should find a version number for real_package" do
        @resource[:name] = "real_package"
        @provider.latest.should_not == nil
      end

      it "should not find a version number for fake_package" do
        @resource[:name] = "fake_package"
        @provider.latest.should == nil
      end

      it "should handle a timeout gracefully" do
        @resource[:name] = "fake_package"
        @client.stubs(:call).raises(Timeout::Error)
        lambda { @provider.latest }.should raise_error(Puppet::Error)
      end

    end

    context "connecting via a proxy" do
      before :each do
        Puppet::Util::HttpProxy.expects(:http_proxy_host).returns 'some_host'
        Puppet::Util::HttpProxy.expects(:http_proxy_port).returns 'some_port'
        XMLRPC::Client.expects(:new2).with("http://pypi.python.org/pypi", "some_host:some_port").returns(@client)
      end

      it "should find a version number for real_package" do
        @resource[:name] = "real_package"
        @provider.latest.should_not == nil
      end

      it "should not find a version number for fake_package" do
        @resource[:name] = "fake_package"
        @provider.latest.should == nil
      end

      it "should handle a timeout gracefully" do
        @resource[:name] = "fake_package"
        @client.stubs(:call).raises(Timeout::Error)
        lambda { @provider.latest }.should raise_error(Puppet::Error)
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

    it "should succeed if pip is present" do
      @provider.stubs(:pip).returns(nil)
      @provider.method(:lazy_pip).call "freeze"
    end

    osfamilies.each do |osfamily, pip_cmd|
      it "should retry on #{osfamily} if #{pip_cmd} has not yet been found" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        @provider.expects(:pip).twice.with('freeze').raises(NoMethodError).then.returns(nil)
        @provider.expects(:which).with(pip_cmd).returns("/fake/bin/pip")
        @provider.method(:lazy_pip).call "freeze"
      end

      it "should fail on #{osfamily} if #{pip_cmd} is missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        @provider.expects(:pip).with('freeze').raises(NoMethodError)
        @provider.expects(:which).with(pip_cmd).returns(nil)
        expect { @provider.method(:lazy_pip).call("freeze") }.to raise_error(NoMethodError)
      end

      it "should output a useful error message on #{osfamily} if #{pip_cmd} is missing" do
        Facter.stubs(:value).with(:osfamily).returns(osfamily.first)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns(osfamily.last)
        @provider.expects(:pip).with('freeze').raises(NoMethodError)
        @provider.expects(:which).with(pip_cmd).returns(nil)
        expect { @provider.method(:lazy_pip).call("freeze") }.
          to raise_error(NoMethodError, 'Could not locate the pip command.')
      end

    end

  end

end
