#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/type/mount'

describe Puppet::Type::Mount do
    it "should have a :refreshable feature that requires the :remount method" do
        Puppet::Type::Mount.provider_feature(:refreshable).methods.should == [:remount]
    end

    it "should have no default value for :ensure" do
        mount = Puppet::Type::Mount.create(:name => "yay")
        mount.should(:ensure).should be_nil
    end
end

describe Puppet::Type::Mount, "when validating attributes" do
    [:name, :remounts].each do |param|
        it "should have a #{param} parameter" do
            Puppet::Type::Mount.attrtype(param).should == :param
        end
    end

    [:ensure, :device, :blockdevice, :fstype, :options, :pass, :dump, :atboot, :target].each do |param|
        it "should have a #{param} property" do
            Puppet::Type::Mount.attrtype(param).should == :property
        end
    end
end

describe Puppet::Type::Mount::Ensure, "when validating values" do
    before do
        @provider = stub 'provider', :class => Puppet::Type::Mount.defaultprovider, :clear => nil
        Puppet::Type::Mount.defaultprovider.expects(:new).returns(@provider)
    end

    it "should support :present as a value to :ensure" do
        Puppet::Type::Mount.create(:name => "yay", :ensure => :present)
    end

    it "should alias :unmounted to :present as a value to :ensure" do
        mount = Puppet::Type::Mount.create(:name => "yay", :ensure => :unmounted)
        mount.should(:ensure).should == :present
    end

    it "should support :absent as a value to :ensure" do
        Puppet::Type::Mount.create(:name => "yay", :ensure => :absent)
    end

    it "should support :mounted as a value to :ensure" do
        Puppet::Type::Mount.create(:name => "yay", :ensure => :mounted)
    end
end

describe Puppet::Type::Mount::Ensure do
    before :each do
        @provider = stub 'provider', :class => Puppet::Type::Mount.defaultprovider, :clear => nil, :satisfies? => true, :name => :mock
        Puppet::Type::Mount.defaultprovider.stubs(:new).returns(@provider)
        @mount = Puppet::Type::Mount.create(:name => "yay", :check => :ensure)

        @ensure = @mount.property(:ensure)
    end

    def mount_stub(params)
        Puppet::Type::Mount.validproperties.each do |prop|
            unless params[prop]
                params[prop] = :absent
                @mount[prop] = :absent
            end
        end

        params.each do |param, value|
            @provider.stubs(param).returns(value)
        end
    end

    describe Puppet::Type::Mount::Ensure, "when retrieving its current state" do

        it "should return the provider's value if it is :absent" do
            @provider.expects(:ensure).returns(:absent)
            @ensure.retrieve.should == :absent
        end

        it "should return :mounted if the provider indicates it is mounted and the value is not :absent" do
            @provider.expects(:ensure).returns(:present)
            @provider.expects(:mounted?).returns(true)
            @ensure.retrieve.should == :mounted
        end

        it "should return :present if the provider indicates it is not mounted and the value is not :absent" do
            @provider.expects(:ensure).returns(:present)
            @provider.expects(:mounted?).returns(false)
            @ensure.retrieve.should == :present
        end
    end

    describe Puppet::Type::Mount::Ensure, "when changing the host" do

        it "should destroy itself if it should be absent" do
            @provider.stubs(:mounted?).returns(false)
            @provider.expects(:destroy)
            @ensure.should = :absent
            @ensure.sync
        end

        it "should unmount itself before destroying if it is mounted and should be absent" do
            @provider.expects(:mounted?).returns(true)
            @provider.expects(:unmount)
            @provider.expects(:destroy)
            @ensure.should = :absent
            @ensure.sync
        end

        it "should create itself if it is absent and should be present" do
            @provider.stubs(:mounted?).returns(false)
            @provider.expects(:create)
            @ensure.should = :present
            @ensure.sync
        end

        it "should unmount itself if it is mounted and should be present" do
            @provider.stubs(:mounted?).returns(true)

            # The interface here is just too much work to test right now.
            @ensure.stubs(:syncothers)
            @provider.expects(:unmount)
            @ensure.should = :present
            @ensure.sync
        end

        it "should create and mount itself if it does not exist and should be mounted" do
            @provider.stubs(:ensure).returns(:absent)
            @provider.stubs(:mounted?).returns(false)
            @provider.expects(:create)
            @ensure.stubs(:syncothers)
            @provider.expects(:mount)
            @ensure.should = :mounted
            @ensure.sync
        end

        it "should mount itself if it is present and should be mounted" do
            @provider.stubs(:ensure).returns(:present)
            @provider.stubs(:mounted?).returns(false)
            @ensure.stubs(:syncothers)
            @provider.expects(:mount)
            @ensure.should = :mounted
            @ensure.sync
        end

        it "should create but not mount itself if it is absent and mounted and should be mounted" do
            @provider.stubs(:ensure).returns(:absent)
            @provider.stubs(:mounted?).returns(true)
            @ensure.stubs(:syncothers)
            @provider.expects(:create)
            @ensure.should = :mounted
            @ensure.sync
        end
    end

    describe Puppet::Type::Mount, "when responding to events" do

        it "should remount if it is currently mounted" do
            @provider.expects(:mounted?).returns(true)
            @provider.expects(:remount)

            @mount.refresh
        end

        it "should not remount if it is not currently mounted" do
            @provider.expects(:mounted?).returns(false)
            @provider.expects(:remount).never

            @mount.refresh
        end

        it "should not remount swap filesystems" do
            @mount[:fstype] = "swap"
            @provider.expects(:remount).never

            @mount.refresh
        end
    end
end
