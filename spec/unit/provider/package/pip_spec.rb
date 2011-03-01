#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

provider_class = Puppet::Type.type(:package).provider(:pip)

describe provider_class do

  before do
    @resource = stub("resource")
    @provider = provider_class.new
    @provider.instance_variable_set(:@resource, @resource)
  end

  describe "parse" do

    it "should return a hash on valid input" do
      provider_class.parse("Django==1.2.5").should == {
        :ensure => "1.2.5",
        :name => "Django",
        :provider => :pip,
      }
    end

    it "should return nil on invalid input" do
      provider_class.parse("foo").should == nil
    end

  end

  describe "instances" do

    it "should return an array when pip is present" do
      provider_class.expects(:command).with(:pip).returns("/fake/bin/pip")
      p = stub("process")
      p.expects(:collect).yields("Django==1.2.5")
      provider_class.expects(:execpipe).with("/fake/bin/pip freeze").yields(p)
      provider_class.instances
    end

    it "should return an empty array when pip is missing" do
      provider_class.expects(:command).with(:pip).raises(
        Puppet::DevError.new("Pretend pip isn't installed."))
      provider_class.instances.should == []
    end

  end

  describe "query" do

    before do
      @resource.stubs(:[]).with(:name).returns("Django")
    end

    it "should return a hash when pip and the package are present" do
      @provider.expects(:command).with(:pip).returns("/fake/bin/pip")
      p = stub("process")
      p.expects(:each).yields("Django==1.2.5")
      @provider.expects(:execpipe).with("/fake/bin/pip freeze").yields(p)
      @provider.query.should == {
        :ensure => "1.2.5",
        :name => "Django",
        :provider => :pip,
      }
    end

    it "should return nil when pip is missing" do
      @provider.expects(:command).with(:pip).raises(
        Puppet::DevError.new("Pretend pip isn't installed."))
      @provider.query.should == nil
    end

    it "should return nil when the package is missing" do
      @provider.expects(:command).with(:pip).returns("/fake/bin/pip")
      p = stub("process")
      p.expects(:each).yields("sdsfdssdhdfyjymdgfcjdfjxdrssf==0.0.0")
      @provider.expects(:execpipe).with("/fake/bin/pip freeze").yields(p)
      @provider.query.should == nil
    end

  end

  describe "latest" do

    it "should find a version number for Django" do
      @resource.stubs(:[]).with(:name).returns "Django"
      @provider.latest.should_not == nil
    end

    it "should not find a version number for sdsfdssdhdfyjymdgfcjdfjxdrssf" do
      @resource.stubs(:[]).with(:name).returns "sdsfdssdhdfyjymdgfcjdfjxdrssf"
      @provider.latest.should == nil
    end

  end

  describe "install" do

    before do
      @resource.stubs(:[]).with(:name).returns("sdsfdssdhdfyjymdgfcjdfjxdrssf")
      @url = "git+https://example.com/sdsfdssdhdfyjymdgfcjdfjxdrssf.git"
    end

    it "should install" do
      @resource.stubs(:[]).with(:ensure).returns(:installed)
      @resource.stubs(:[]).with(:source).returns(nil)
      @provider.expects(:lazy_pip).with do |*args|
        "install" == args[0] && "sdsfdssdhdfyjymdgfcjdfjxdrssf" == args[-1]
      end.returns nil
      @provider.install
    end

    it "should install from SCM" do
      @resource.stubs(:[]).with(:ensure).returns(:installed)
      @resource.stubs(:[]).with(:source).returns(@url)
      @provider.expects(:lazy_pip).with do |*args|
        "#{@url}#egg=sdsfdssdhdfyjymdgfcjdfjxdrssf" == args[-1]
      end.returns nil
      @provider.install
    end

    it "should install a particular revision" do
      @resource.stubs(:[]).with(:ensure).returns("0123456")
      @resource.stubs(:[]).with(:source).returns(@url)
      @provider.expects(:lazy_pip).with do |*args|
        "#{@url}@0123456#egg=sdsfdssdhdfyjymdgfcjdfjxdrssf" == args[-1]
      end.returns nil
      @provider.install
    end

    it "should install a particular version" do
      @resource.stubs(:[]).with(:ensure).returns("0.0.0")
      @resource.stubs(:[]).with(:source).returns(nil)
      @provider.expects(:lazy_pip).with do |*args|
        "sdsfdssdhdfyjymdgfcjdfjxdrssf==0.0.0" == args[-1]
      end.returns nil
      @provider.install
    end

    it "should upgrade" do
      @resource.stubs(:[]).with(:ensure).returns(:latest)
      @resource.stubs(:[]).with(:source).returns(nil)
      @provider.expects(:lazy_pip).with do |*args|
        "--upgrade" == args[-2] && "sdsfdssdhdfyjymdgfcjdfjxdrssf" == args[-1]
      end.returns nil
      @provider.install
    end

  end

  describe "uninstall" do

    it "should uninstall" do
      @resource.stubs(:[]).with(:name).returns("sdsfdssdhdfyjymdgfcjdfjxdrssf")
      @provider.expects(:lazy_pip).returns(nil)
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

    it "should succeed if pip is present" do
      @provider.stubs(:pip).returns(nil)
      @provider.method(:lazy_pip).call "freeze"
    end

    it "should retry if pip has not yet been found" do
      @provider.stubs(:pip).raises(NoMethodError).returns("/fake/bin/pip")
      @provider.method(:lazy_pip).call "freeze"
    end

    it "should fail if pip is missing" do
      @provider.stubs(:pip).twice.raises(NoMethodError)
      expect { @provider.method(:lazy_pip).call("freeze") }.to \
        raise_error(NoMethodError)
    end

  end

end
