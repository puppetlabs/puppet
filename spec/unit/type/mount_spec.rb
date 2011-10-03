#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:mount), :unless => Puppet.features.microsoft_windows? do
  it "should have a :refreshable feature that requires the :remount method" do
    Puppet::Type.type(:mount).provider_feature(:refreshable).methods.should == [:remount]
  end

  it "should have no default value for :ensure" do
    mount = Puppet::Type.type(:mount).new(:name => "yay")
    mount.should(:ensure).should be_nil
  end

  it "should have :name as the only keyattribut" do
    Puppet::Type.type(:mount).key_attributes.should == [:name]
  end
end

describe Puppet::Type.type(:mount), "when validating attributes" do
  [:name, :remounts, :provider].each do |param|
    it "should have a #{param} parameter" do
      Puppet::Type.type(:mount).attrtype(param).should == :param
    end
  end

  [:ensure, :device, :blockdevice, :fstype, :options, :pass, :dump, :atboot, :target].each do |param|
    it "should have a #{param} property" do
      Puppet::Type.type(:mount).attrtype(param).should == :property
    end
  end
end

describe Puppet::Type.type(:mount)::Ensure, "when validating values", :unless => Puppet.features.microsoft_windows? do
  before do
    @provider = stub 'provider', :class => Puppet::Type.type(:mount).defaultprovider, :clear => nil
    Puppet::Type.type(:mount).defaultprovider.expects(:new).returns(@provider)
  end

  it "should alias :present to :defined as a value to :ensure" do
    mount = Puppet::Type.type(:mount).new(:name => "yay", :ensure => :present)
    mount.should(:ensure).should == :defined
  end

  it "should support :present as a value to :ensure" do
    Puppet::Type.type(:mount).new(:name => "yay", :ensure => :present)
  end

  it "should support :defined as a value to :ensure" do
    Puppet::Type.type(:mount).new(:name => "yay", :ensure => :defined)
  end

  it "should support :unmounted as a value to :ensure" do
    Puppet::Type.type(:mount).new(:name => "yay", :ensure => :unmounted)
  end

  it "should support :absent as a value to :ensure" do
    Puppet::Type.type(:mount).new(:name => "yay", :ensure => :absent)
  end

  it "should support :mounted as a value to :ensure" do
    Puppet::Type.type(:mount).new(:name => "yay", :ensure => :mounted)
  end
end

describe Puppet::Type.type(:mount)::Ensure, :unless => Puppet.features.microsoft_windows? do
  before :each do
    provider_properties = {}
    @provider = stub 'provider', :class => Puppet::Type.type(:mount).defaultprovider, :clear => nil, :satisfies? => true, :name => :mock, :property_hash => provider_properties
    Puppet::Type.type(:mount).defaultprovider.stubs(:new).returns(@provider)
    @mount = Puppet::Type.type(:mount).new(:name => "yay", :check => :ensure)

    @ensure = @mount.property(:ensure)
  end

  def mount_stub(params)
    Puppet::Type.type(:mount).validproperties.each do |prop|
      unless params[prop]
        params[prop] = :absent
        @mount[prop] = :absent
      end
    end

    params.each do |param, value|
      @provider.stubs(param).returns(value)
    end
  end

  describe Puppet::Type.type(:mount)::Ensure, "when changing the host" do

    def test_ensure_change(options)
      @provider.stubs(:get).with(:ensure).returns options[:from]
      @provider.stubs(:ensure).returns options[:from]
      @provider.stubs(:mounted?).returns([:mounted,:ghost].include? options[:from])
      @provider.expects(:create).times(options[:create] || 0)
      @provider.expects(:destroy).times(options[:destroy] || 0)
      @provider.expects(:mount).never
      @provider.expects(:unmount).times(options[:unmount] || 0)
      @ensure.stubs(:syncothers)
      @ensure.should = options[:to]
      @ensure.sync
      (!!@provider.property_hash[:needs_mount]).should == (!!options[:mount])
   end

   it "should create itself when changing from :ghost to :present" do
     test_ensure_change(:from => :ghost, :to => :present, :create => 1)
   end

   it "should create itself when changing from :absent to :present" do
     test_ensure_change(:from => :absent, :to => :present, :create => 1)
   end

   it "should create itself and unmount when changing from :ghost to :unmounted" do
     test_ensure_change(:from => :ghost, :to => :unmounted, :create => 1, :unmount => 1)
   end

   it "should unmount resource when changing from :mounted to :unmounted" do
     test_ensure_change(:from => :mounted, :to => :unmounted, :unmount => 1)
   end

   it "should create itself when changing from :absent to :unmounted" do
     test_ensure_change(:from => :absent, :to => :unmounted, :create => 1)
   end

   it "should unmount resource when changing from :ghost to :absent" do
     test_ensure_change(:from => :ghost, :to => :absent, :unmount => 1)
   end

   it "should unmount and destroy itself when changing from :mounted to :absent" do
     test_ensure_change(:from => :mounted, :to => :absent, :destroy => 1, :unmount => 1)
   end

   it "should destroy itself when changing from :unmounted to :absent" do
     test_ensure_change(:from => :unmounted, :to => :absent, :destroy => 1)
   end

   it "should create itself when changing from :ghost to :mounted" do
     test_ensure_change(:from => :ghost, :to => :mounted, :create => 1)
   end

   it "should create itself and mount when changing from :absent to :mounted" do
     test_ensure_change(:from => :absent, :to => :mounted, :create => 1, :mount => 1)
   end

   it "should mount resource when changing from :unmounted to :mounted" do
     test_ensure_change(:from => :unmounted, :to => :mounted, :mount => 1)
   end


   it "should be in sync if it is :absent and should be :absent" do
     @ensure.should = :absent
     @ensure.safe_insync?(:absent).should == true
   end

   it "should be out of sync if it is :absent and should be :defined" do
     @ensure.should = :defined
     @ensure.safe_insync?(:absent).should == false
   end

   it "should be out of sync if it is :absent and should be :mounted" do
     @ensure.should = :mounted
     @ensure.safe_insync?(:absent).should == false
   end

   it "should be out of sync if it is :absent and should be :unmounted" do
     @ensure.should = :unmounted
     @ensure.safe_insync?(:absent).should == false
   end

   it "should be out of sync if it is :mounted and should be :absent" do
     @ensure.should = :absent
     @ensure.safe_insync?(:mounted).should == false
   end

   it "should be in sync if it is :mounted and should be :defined" do
     @ensure.should = :defined
     @ensure.safe_insync?(:mounted).should == true
   end

   it "should be in sync if it is :mounted and should be :mounted" do
     @ensure.should = :mounted
     @ensure.safe_insync?(:mounted).should == true
   end

   it "should be out in sync if it is :mounted and should be :unmounted" do
     @ensure.should = :unmounted
     @ensure.safe_insync?(:mounted).should == false
   end


   it "should be out of sync if it is :unmounted and should be :absent" do
     @ensure.should = :absent
     @ensure.safe_insync?(:unmounted).should == false
   end

   it "should be in sync if it is :unmounted and should be :defined" do
     @ensure.should = :defined
     @ensure.safe_insync?(:unmounted).should == true
   end

   it "should be out of sync if it is :unmounted and should be :mounted" do
     @ensure.should = :mounted
     @ensure.safe_insync?(:unmounted).should == false
   end

   it "should be in sync if it is :unmounted and should be :unmounted" do
     @ensure.should = :unmounted
     @ensure.safe_insync?(:unmounted).should == true
   end


   it "should be out of sync if it is :ghost and should be :absent" do
     @ensure.should = :absent
     @ensure.safe_insync?(:ghost).should == false
   end

   it "should be out of sync if it is :ghost and should be :defined" do
     @ensure.should = :defined
     @ensure.safe_insync?(:ghost).should == false
   end

   it "should be out of sync if it is :ghost and should be :mounted" do
     @ensure.should = :mounted
     @ensure.safe_insync?(:ghost).should == false
   end

   it "should be out of sync if it is :ghost and should be :unmounted" do
     @ensure.should = :unmounted
     @ensure.safe_insync?(:ghost).should == false
   end

 end

  describe Puppet::Type.type(:mount), "when responding to refresh" do
    pending "2.6.x specifies slightly different behavior and the desired behavior needs to be clarified and revisited.  See ticket #4904" do

      it "should remount if it is supposed to be mounted" do
        @mount[:ensure] = "mounted"
        @provider.expects(:remount)

        @mount.refresh
      end

      it "should not remount if it is supposed to be present" do
        @mount[:ensure] = "present"
        @provider.expects(:remount).never

        @mount.refresh
      end

      it "should not remount if it is supposed to be absent" do
        @mount[:ensure] = "absent"
        @provider.expects(:remount).never

        @mount.refresh
      end

      it "should not remount if it is supposed to be defined" do
        @mount[:ensure] = "defined"
        @provider.expects(:remount).never

        @mount.refresh
      end

      it "should not remount if it is supposed to be unmounted" do
        @mount[:ensure] = "unmounted"
        @provider.expects(:remount).never

        @mount.refresh
      end

      it "should not remount swap filesystems" do
        @mount[:ensure] = "mounted"
        @mount[:fstype] = "swap"
        @provider.expects(:remount).never

        @mount.refresh
      end
    end
  end
end

describe Puppet::Type.type(:mount), "when modifying an existing mount entry", :unless => Puppet.features.microsoft_windows? do
  before do
    @provider = stub 'provider', :class => Puppet::Type.type(:mount).defaultprovider, :clear => nil, :satisfies? => true, :name => :mock, :remount => nil
    Puppet::Type.type(:mount).defaultprovider.stubs(:new).returns(@provider)
    @mount = Puppet::Type.type(:mount).new(:name => "yay", :ensure => :mounted)

    {:device => "/foo/bar", :blockdevice => "/other/bar", :target => "/what/ever", :fstype => 'eh', :options => "", :pass => 0, :dump => 0, :atboot => 0,
      :ensure => :mounted}.each do
      |param, value|
      @mount.provider.stubs(param).returns value
      @mount[param] = value
    end

    @mount.provider.stubs(:mounted?).returns true

    # stub this to not try to create state.yaml
    Puppet::Util::Storage.stubs(:store)

    @catalog = Puppet::Resource::Catalog.new
    @catalog.add_resource @mount
  end

  it "should use the provider to change the dump value" do
    @mount.provider.expects(:dump).returns 0
    @mount.provider.expects(:dump=).with(1)

    @mount[:dump] = 1

    @catalog.apply
  end

  it "should umount before flushing changes to disk" do
    syncorder = sequence('syncorder')
    @mount.provider.expects(:options).returns 'soft'
    @mount.provider.expects(:ensure).returns :mounted

    @mount.provider.expects(:unmount).in_sequence(syncorder)
    @mount.provider.expects(:options=).in_sequence(syncorder).with 'hard'
    @mount.expects(:flush).in_sequence(syncorder) # Call inside syncothers
    @mount.expects(:flush).in_sequence(syncorder) # I guess transaction or anything calls flush again

    @mount[:ensure] = :unmounted
    @mount[:options] = 'hard'

    @catalog.apply
  end

end
