#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet/provider/nameservice'
require 'etc'

describe Puppet::Provider::NameService do

  before :each do
    described_class.initvars
    described_class.resource_type = faketype
  end

  # These are values getpwent might give you
  let :users do
    [
      Struct::Passwd.new('root', 'x', 0, 0),
      Struct::Passwd.new('foo', 'x', 1000, 2000),
      nil
    ]
  end

  # These are values getgrent might give you
  let :groups do
    [
      Struct::Group.new('root', 'x', 0, %w{root}),
      Struct::Group.new('bin', 'x', 1, %w{root bin daemon}),
      nil
    ]
  end

  # A fake struct besides Struct::Group and Struct::Passwd
  let :fakestruct do
    Struct.new(:foo, :bar)
  end

  # A fake value get<foo>ent might return
  let :fakeetcobject do
    fakestruct.new('fooval', 'barval')
  end

  # The provider sometimes relies on @resource for valid properties so let's
  # create a fake type with properties that match our fake struct.
  let :faketype do
    Puppet::Type.newtype(:nameservice_dummytype) do
      newparam(:name)
      ensurable
      newproperty(:foo)
      newproperty(:bar)
    end
  end

  let :provider do
    described_class.new(:name => 'bob', :foo => 'fooval', :bar => 'barval')
  end

  let :resource do
    resource = faketype.new(:name => 'bob', :ensure => :present)
    resource.provider = provider
    resource
  end

  describe "#options" do
    it "should add options for a valid property" do
      described_class.options :foo, :key1 => 'val1', :key2 => 'val2'
      described_class.options :bar, :key3 => 'val3'
      described_class.option(:foo, :key1).should == 'val1'
      described_class.option(:foo, :key2).should == 'val2'
      described_class.option(:bar, :key3).should == 'val3'
    end

    it "should raise an error for an invalid property" do
      expect { described_class.options :baz, :key1 => 'val1' }.to raise_error(
        Puppet::Error, 'baz is not a valid attribute for nameservice_dummytype')
    end
  end

  describe "#option" do
    it "should return the correct value" do
      described_class.options :foo, :key1 => 'val1', :key2 => 'val2'
      described_class.option(:foo, :key2).should == 'val2'
    end

    it "should symbolize the name first" do
      described_class.options :foo, :key1 => 'val1', :key2 => 'val2'
      described_class.option('foo', :key2).should == 'val2'
    end

    it "should return nil if no option has been specified earlier" do
      described_class.option(:foo, :key2).should be_nil
    end

    it "should return nil if no option for that property has been specified earlier" do
      described_class.options :bar, :key2 => 'val2'
      described_class.option(:foo, :key2).should be_nil
    end

    it "should return nil if no matching key can be found for that property" do
      described_class.options :foo, :key3 => 'val2'
      described_class.option(:foo, :key2).should be_nil
    end
  end

  describe "#section" do
    it "should raise an error if resource_type has not been set" do
      described_class.expects(:resource_type).returns nil
      expect { described_class.section }.to raise_error Puppet::Error, 'Cannot determine Etc section without a resource type'
    end

    # the return values are hard coded so I am using types that actually make
    # use of the nameservice provider
    it "should return pw for users" do
      described_class.resource_type = Puppet::Type.type(:user)
      described_class.section.should == 'pw'
    end

    it "should return gr for groups" do
      described_class.resource_type = Puppet::Type.type(:group)
      described_class.section.should == 'gr'
    end
  end

  describe "#listbyname" do
    it "should return a list of users if resource_type is user" do
      described_class.resource_type = Puppet::Type.type(:user)
      Etc.expects(:setpwent)
      Etc.stubs(:getpwent).returns *users
      Etc.expects(:endpwent)
      described_class.listbyname.should == %w{root foo}
    end

    it "should return a list of groups if resource_type is group", :unless => Puppet.features.microsoft_windows? do
      described_class.resource_type = Puppet::Type.type(:group)
      Etc.expects(:setgrent)
      Etc.stubs(:getgrent).returns *groups
      Etc.expects(:endgrent)
      described_class.listbyname.should == %w{root bin}
    end

    it "should yield if a block given" do
      yield_results = []
      described_class.resource_type = Puppet::Type.type(:user)
      Etc.expects(:setpwent)
      Etc.stubs(:getpwent).returns *users
      Etc.expects(:endpwent)
      described_class.listbyname {|x| yield_results << x }
      yield_results.should == %w{root foo}
    end
  end

  describe "instances" do
    it "should return a list of objects based on listbyname" do
      described_class.expects(:listbyname).multiple_yields 'root', 'foo', 'nobody'
      described_class.instances.map(&:name).should == %w{root foo nobody}
    end
  end

  describe "validate" do
    it "should pass if no check is registered at all" do
      expect { described_class.validate(:foo, 300) }.to_not raise_error
      expect { described_class.validate('foo', 300) }.to_not raise_error
    end

    it "should pass if no check for that property is registered" do
      described_class.verify(:bar, 'Must be 100') { |val| val == 100 }
      expect { described_class.validate(:foo, 300) }.to_not raise_error
      expect { described_class.validate('foo', 300) }.to_not raise_error
    end

    it "should pass if the value is valid" do
      described_class.verify(:foo, 'Must be 100') { |val| val == 100 }
      expect { described_class.validate(:foo, 100) }.to_not raise_error
      expect { described_class.validate('foo', 100) }.to_not raise_error
    end

    it "should raise an error if the value is invalid" do
      described_class.verify(:foo, 'Must be 100') { |val| val == 100 }
      expect { described_class.validate(:foo, 200) }.to raise_error(ArgumentError, 'Invalid value 200: Must be 100')
      expect { described_class.validate('foo', 200) }.to raise_error(ArgumentError, 'Invalid value 200: Must be 100')
    end
  end

  describe "getinfo" do
    before :each do
      # with section=foo we'll call Etc.getfoonam instead of getpwnam or getgrnam
      described_class.stubs(:section).returns 'foo'
      resource # initialize the resource so our provider has a @resource instance variable
    end

    it "should return a hash if we can retrieve something" do
      Etc.expects(:send).with(:getfoonam, 'bob').returns fakeetcobject
      provider.expects(:info2hash).with(fakeetcobject).returns(:foo => 'fooval', :bar => 'barval')
      provider.getinfo(true).should == {:foo => 'fooval', :bar => 'barval'}
    end

    it "should return nil if we cannot retrieve anything" do
      Etc.expects(:send).with(:getfoonam, 'bob').raises(ArgumentError, "can't find bob")
      provider.expects(:info2hash).never
      provider.getinfo(true).should be_nil
    end
  end

  describe "info2hash" do
    it "should return a hash with all properties" do
      # we have to have an implementation of posixmethod which has to
      # convert a propertyname (e.g. comment) into a fieldname of our
      # Struct (e.g. gecos). I do not want to test posixmethod here so
      # let's fake an implementation which does not do any translation. We
      # expect two method invocations because info2hash calls the method
      # twice if the Struct responds to the propertyname (our fake Struct
      # provides values for :foo and :bar) TODO: Fix that
      provider.expects(:posixmethod).with(:foo).returns(:foo).twice
      provider.expects(:posixmethod).with(:bar).returns(:bar).twice
      provider.expects(:posixmethod).with(:ensure).returns :ensure
      provider.info2hash(fakeetcobject).should == { :foo => 'fooval', :bar => 'barval' }
    end
  end

  describe "munge" do
    it "should return the input value if no munge method has be defined" do
      provider.munge(:foo, 100).should == 100
    end

    it "should return the munged value otherwise" do
      described_class.options(:foo, :munge => proc { |x| x*2 })
      provider.munge(:foo, 100).should == 200
    end
  end

  describe "unmunge" do
    it "should return the input value if no unmunge method has been defined" do
      provider.unmunge(:foo, 200).should == 200
    end

    it "should return the unmunged value otherwise" do
      described_class.options(:foo, :unmunge => proc { |x| x/2 })
      provider.unmunge(:foo, 200).should == 100
    end
  end


  describe "exists?" do
    it "should return true if we can retrieve anything" do
      provider.expects(:getinfo).with(true).returns(:foo => 'fooval', :bar => 'barval')
      provider.should be_exists
    end
    it "should return false if we cannot retrieve anything" do
      provider.expects(:getinfo).with(true).returns nil
      provider.should_not be_exists
    end
  end

  describe "get" do
    before(:each) {described_class.resource_type = faketype }

    it "should return the correct getinfo value" do
      provider.expects(:getinfo).with(false).returns(:foo => 'fooval', :bar => 'barval')
      provider.get(:bar).should == 'barval'
    end

    it "should unmunge the value first" do
      described_class.options(:bar, :munge => proc { |x| x*2}, :unmunge => proc {|x| x/2})
      provider.expects(:getinfo).with(false).returns(:foo => 200, :bar => 500)
      provider.get(:bar).should == 250
    end

    it "should return nil if getinfo cannot retrieve the value" do
      provider.expects(:getinfo).with(false).returns(:foo => 'fooval', :bar => 'barval')
      provider.get(:no_such_key).should be_nil
    end

  end

  describe "set" do
    before :each do
      resource # initialize resource so our provider has a @resource object
      described_class.verify(:foo, 'Must be 100') { |val| val == 100 }
    end

    it "should raise an error on invalid values" do
      expect { provider.set(:foo, 200) }.to raise_error(ArgumentError, 'Invalid value 200: Must be 100')
    end

    it "should execute the modify command on valid values" do
      provider.expects(:modifycmd).with(:foo, 100).returns ['/bin/modify', '-f', '100' ]
      provider.expects(:execute).with ['/bin/modify', '-f', '100']
      provider.set(:foo, 100)
    end

    it "should munge the value first" do
      described_class.options(:foo, :munge => proc { |x| x*2}, :unmunge => proc {|x| x/2})
      provider.expects(:modifycmd).with(:foo, 200).returns ['/bin/modify', '-f', '200' ]
      provider.expects(:execute).with ['/bin/modify', '-f', '200']
      provider.set(:foo, 100)
    end

    it "should fail if the modify command fails" do
      provider.expects(:modifycmd).with(:foo, 100).returns ['/bin/modify', '-f', '100' ]
      provider.expects(:execute).with(['/bin/modify', '-f', '100']).raises(Puppet::ExecutionFailure, "Execution of '/bin/modify' returned 1: some_failure")
      expect { provider.set(:foo, 100) }.to raise_error Puppet::Error, /Could not set foo/
    end
  end

end
