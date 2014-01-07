#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:service) do
  it "should have an :enableable feature that requires the :enable, :disable, and :enabled? methods" do
    Puppet::Type.type(:service).provider_feature(:enableable).methods.should == [:disable, :enable, :enabled?]
  end

  it "should have a :refreshable feature that requires the :restart method" do
    Puppet::Type.type(:service).provider_feature(:refreshable).methods.should == [:restart]
  end
end

describe Puppet::Type.type(:service), "when validating attributes" do
  [:name, :binary, :hasstatus, :path, :pattern, :start, :restart, :stop, :status, :hasrestart, :control].each do |param|
    it "should have a #{param} parameter" do
      Puppet::Type.type(:service).attrtype(param).should == :param
    end
  end

  [:ensure, :enable].each do |param|
    it "should have an #{param} property" do
      Puppet::Type.type(:service).attrtype(param).should == :property
    end
  end
end

describe Puppet::Type.type(:service), "when validating attribute values" do
  before do
    @provider = stub 'provider', :class => Puppet::Type.type(:service).defaultprovider, :clear => nil, :controllable? => false
    Puppet::Type.type(:service).defaultprovider.stubs(:new).returns(@provider)
  end

  it "should support :running as a value to :ensure" do
    Puppet::Type.type(:service).new(:name => "yay", :ensure => :running)
  end

  it "should support :stopped as a value to :ensure" do
    Puppet::Type.type(:service).new(:name => "yay", :ensure => :stopped)
  end

  it "should alias the value :true to :running in :ensure" do
    svc = Puppet::Type.type(:service).new(:name => "yay", :ensure => true)
    svc.should(:ensure).should == :running
  end

  it "should alias the value :false to :stopped in :ensure" do
    svc = Puppet::Type.type(:service).new(:name => "yay", :ensure => false)
    svc.should(:ensure).should == :stopped
  end

  describe "the enable property" do
    before :each do
      @provider.class.stubs(:supports_parameter?).returns true
    end
    it "should support :true as a value" do
      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :true)
      srv.should(:enable).should == :true
    end

    it "should support :false as a value" do
      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :false)
      srv.should(:enable).should == :false
    end

    it "should support :manual as a value on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns true

      srv = Puppet::Type.type(:service).new(:name => "yay", :enable => :manual)
      srv.should(:enable).should == :manual
    end

    it "should not support :manual as a value when not on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns false

      expect { Puppet::Type.type(:service).new(:name => "yay", :enable => :manual) }.to raise_error(
        Puppet::Error,
        /Setting enable to manual is only supported on Microsoft Windows\./
      )
    end
  end

  it "should support :true as a value to :hasstatus" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasstatus => :true)
    srv[:hasstatus].should == :true
  end

  it "should support :false as a value to :hasstatus" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasstatus => :false)
    srv[:hasstatus].should == :false
  end

  it "should specify :true as the default value of hasstatus" do
    srv = Puppet::Type.type(:service).new(:name => "yay")
    srv[:hasstatus].should == :true
  end

  it "should support :true as a value to :hasrestart" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasrestart => :true)
    srv[:hasrestart].should == :true
  end

  it "should support :false as a value to :hasrestart" do
    srv = Puppet::Type.type(:service).new(:name => "yay", :hasrestart => :false)
    srv[:hasrestart].should == :false
  end

  it "should allow setting the :enable parameter if the provider has the :enableable feature" do
    Puppet::Type.type(:service).defaultprovider.stubs(:supports_parameter?).returns(true)
    Puppet::Type.type(:service).defaultprovider.expects(:supports_parameter?).with(Puppet::Type.type(:service).attrclass(:enable)).returns(true)
    svc = Puppet::Type.type(:service).new(:name => "yay", :enable => true)
    svc.should(:enable).should == :true
  end

  it "should not allow setting the :enable parameter if the provider is missing the :enableable feature" do
    Puppet::Type.type(:service).defaultprovider.stubs(:supports_parameter?).returns(true)
    Puppet::Type.type(:service).defaultprovider.expects(:supports_parameter?).with(Puppet::Type.type(:service).attrclass(:enable)).returns(false)
    svc = Puppet::Type.type(:service).new(:name => "yay", :enable => true)
    svc.should(:enable).should be_nil
  end

  it "should split paths on '#{File::PATH_SEPARATOR}'" do
    Puppet::FileSystem.stubs(:exist?).returns(true)
    FileTest.stubs(:directory?).returns(true)
    svc = Puppet::Type.type(:service).new(:name => "yay", :path => "/one/two#{File::PATH_SEPARATOR}/three/four")
    svc[:path].should == %w{/one/two /three/four}
  end

  it "should accept arrays of paths joined by '#{File::PATH_SEPARATOR}'" do
    Puppet::FileSystem.stubs(:exist?).returns(true)
    FileTest.stubs(:directory?).returns(true)
    svc = Puppet::Type.type(:service).new(:name => "yay", :path => ["/one#{File::PATH_SEPARATOR}/two", "/three#{File::PATH_SEPARATOR}/four"])
    svc[:path].should == %w{/one /two /three /four}
  end
end

describe Puppet::Type.type(:service), "when setting default attribute values" do
  it "should default to the provider's default path if one is available" do
    FileTest.stubs(:directory?).returns(true)
    Puppet::FileSystem.stubs(:exist?).returns(true)

    Puppet::Type.type(:service).defaultprovider.stubs(:respond_to?).returns(true)
    Puppet::Type.type(:service).defaultprovider.stubs(:defpath).returns("testing")
    svc = Puppet::Type.type(:service).new(:name => "other")
    svc[:path].should == ["testing"]
  end

  it "should default 'pattern' to the binary if one is provided" do
    svc = Puppet::Type.type(:service).new(:name => "other", :binary => "/some/binary")
    svc[:pattern].should == "/some/binary"
  end

  it "should default 'pattern' to the name if no pattern is provided" do
    svc = Puppet::Type.type(:service).new(:name => "other")
    svc[:pattern].should == "other"
  end

  it "should default 'control' to the upcased service name with periods replaced by underscores if the provider supports the 'controllable' feature" do
    provider = stub 'provider', :controllable? => true, :class => Puppet::Type.type(:service).defaultprovider, :clear => nil
    Puppet::Type.type(:service).defaultprovider.stubs(:new).returns(provider)
    svc = Puppet::Type.type(:service).new(:name => "nfs.client")
    svc[:control].should == "NFS_CLIENT_START"
  end
end

describe Puppet::Type.type(:service), "when retrieving the host's current state" do
  before do
    @service = Puppet::Type.type(:service).new(:name => "yay")
  end

  it "should use the provider's status to determine whether the service is running" do
    @service.provider.expects(:status).returns(:yepper)
    @service[:ensure] = :running
    @service.property(:ensure).retrieve.should == :yepper
  end

  it "should ask the provider whether it is enabled" do
    @service.provider.class.stubs(:supports_parameter?).returns(true)
    @service.provider.expects(:enabled?).returns(:yepper)
    @service[:enable] = true
    @service.property(:enable).retrieve.should == :yepper
  end
end

describe Puppet::Type.type(:service), "when changing the host" do
  before do
    @service = Puppet::Type.type(:service).new(:name => "yay")
  end

  it "should start the service if it is supposed to be running" do
    @service[:ensure] = :running
    @service.provider.expects(:start)
    @service.property(:ensure).sync
  end

  it "should stop the service if it is supposed to be stopped" do
    @service[:ensure] = :stopped
    @service.provider.expects(:stop)
    @service.property(:ensure).sync
  end

  it "should enable the service if it is supposed to be enabled" do
    @service.provider.class.stubs(:supports_parameter?).returns(true)
    @service[:enable] = true
    @service.provider.expects(:enable)
    @service.property(:enable).sync
  end

  it "should disable the service if it is supposed to be disabled" do
    @service.provider.class.stubs(:supports_parameter?).returns(true)
    @service[:enable] = false
    @service.provider.expects(:disable)
    @service.property(:enable).sync
  end

  it "should sync the service's enable state when changing the state of :ensure if :enable is being managed" do
    @service.provider.class.stubs(:supports_parameter?).returns(true)
    @service[:enable] = false
    @service[:ensure] = :stopped

    @service.property(:enable).expects(:retrieve).returns("whatever")
    @service.property(:enable).expects(:insync?).returns(false)
    @service.property(:enable).expects(:sync)

    @service.provider.stubs(:stop)

    @service.property(:ensure).sync
  end
end

describe Puppet::Type.type(:service), "when refreshing the service" do
  before do
    @service = Puppet::Type.type(:service).new(:name => "yay")
  end

  it "should restart the service if it is running" do
    @service[:ensure] = :running
    @service.provider.expects(:status).returns(:running)
    @service.provider.expects(:restart)
    @service.refresh
  end

  it "should restart the service if it is running, even if it is supposed to stopped" do
    @service[:ensure] = :stopped
    @service.provider.expects(:status).returns(:running)
    @service.provider.expects(:restart)
    @service.refresh
  end

  it "should not restart the service if it is not running" do
    @service[:ensure] = :running
    @service.provider.expects(:status).returns(:stopped)
    @service.refresh
  end

  it "should add :ensure as a property if it is not being managed" do
    @service.provider.expects(:status).returns(:running)
    @service.provider.expects(:restart)
    @service.refresh
  end
end
