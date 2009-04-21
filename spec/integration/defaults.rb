#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/defaults'

describe "Puppet defaults" do
        include Puppet::Util::Execution
    after { Puppet.settings.clear }

    describe "when setting the :factpath" do
        it "should add the :factpath to Facter's search paths" do
            Facter.expects(:search).with("/my/fact/path")

            Puppet.settings[:factpath] = "/my/fact/path"
        end
    end

    describe "when setting the :certname" do
        it "should fail if the certname is not downcased" do
            lambda { Puppet.settings[:certname] = "Host.Domain.Com" }.should raise_error(ArgumentError)
        end
    end

    describe "when configuring the :crl" do
        it "should warn if :cacrl is set to false" do
            Puppet.expects(:warning)
            Puppet.settings[:cacrl] = 'false'
        end
    end

    it "should have a clientyamldir setting" do
        Puppet.settings[:clientyamldir].should_not be_nil
    end

    it "should have different values for the yamldir and clientyamldir" do
        Puppet.settings[:yamldir].should_not == Puppet.settings[:clientyamldir]
    end

    # See #1232
    it "should not specify a user or group for the clientyamldir" do
        Puppet.settings.element(:clientyamldir).owner.should be_nil
        Puppet.settings.element(:clientyamldir).group.should be_nil
    end

    # See #1232
    it "should not specify a user or group for the rundir" do
        Puppet.settings.element(:rundir).owner.should be_nil
        Puppet.settings.element(:rundir).group.should be_nil
    end

    it "should default to yaml as the catalog format" do
        Puppet.settings[:catalog_format].should == "yaml"
    end

    it "should default to 0.0.0.0 for its bind address and 'webrick' for its server type" do
        Puppet.settings[:servertype] = "webrick"
        Puppet.settings[:bindaddress].should == "0.0.0.0"
    end

    it "should default to 0.0.0.0 for its bind address if the server is webrick" do
        Puppet.settings[:servertype] = "webrick"
        Puppet.settings[:bindaddress].should == "0.0.0.0"
    end

    it "should default to 127.0.0.1 for its bind address if the server is mongrel" do
        Puppet.settings[:servertype] = "mongrel"
        Puppet.settings[:bindaddress].should == "127.0.0.1"
    end

    it "should allow specification of a different bind address" do
        Puppet.settings[:bindaddress] = "192.168.0.1"
        Puppet.settings[:bindaddress].should == "192.168.0.1"
    end

    [:factdest, :pluginpath].each do |setting|
        it "should force the #{setting} to be a directory" do
            Puppet.settings[setting].should =~ /\/$/
        end
    end

    [:modulepath, :pluginpath, :factpath].each do |setting|
        it "should configure '#{setting}' not to be a file setting, so multi-directory settings are acceptable" do
            Puppet.settings.element(setting).should be_instance_of(Puppet::Util::Settings::CElement)
        end
    end

    it "should add /usr/sbin and /sbin to the path if they're not there" do
        withenv("PATH" => "/usr/bin:/usr/local/bin") do
            Puppet.settings[:path] = "none" # this causes it to ignore the setting
            ENV["PATH"].split(File::PATH_SEPARATOR).should be_include("/usr/sbin")
            ENV["PATH"].split(File::PATH_SEPARATOR).should be_include("/sbin")
        end
    end

    describe "when enabling storeconfigs" do
        before do
            Puppet::Resource::Catalog.stubs(:cache_class=)
            Puppet::Node::Facts.stubs(:cache_class=)
            Puppet::Node.stubs(:cache_class=)
        end

        it "should set the Catalog cache class to :active_record" do
            Puppet::Resource::Catalog.expects(:cache_class=).with(:active_record)
            Puppet.settings[:storeconfigs] = true
        end

        it "should not set the Catalog cache class to :active_record if asynchronous storeconfigs is enabled" do
            Puppet::Resource::Catalog.expects(:cache_class=).with(:active_record).never
            Puppet.settings.expects(:value).with(:async_storeconfigs).returns true
            Puppet.settings[:storeconfigs] = true
        end

        it "should set the Facts cache class to :active_record" do
            Puppet::Node::Facts.expects(:cache_class=).with(:active_record)
            Puppet.settings[:storeconfigs] = true
        end

        it "should set the Node cache class to :active_record" do
            Puppet::Node.expects(:cache_class=).with(:active_record)
            Puppet.settings[:storeconfigs] = true
        end
    end

    describe "when enabling asynchronous storeconfigs" do
        before do
            Puppet::Resource::Catalog.stubs(:cache_class=)
            Puppet::Node::Facts.stubs(:cache_class=)
            Puppet::Node.stubs(:cache_class=)
        end

        it "should set storeconfigs to true" do
            Puppet.settings[:async_storeconfigs] = true
            Puppet.settings[:storeconfigs].should be_true
        end

        it "should set the Catalog cache class to :queue" do
            Puppet::Resource::Catalog.expects(:cache_class=).with(:queue)
            Puppet.settings[:async_storeconfigs] = true
        end

        it "should set the Facts cache class to :active_record" do
            Puppet::Node::Facts.expects(:cache_class=).with(:active_record)
            Puppet.settings[:storeconfigs] = true
        end

        it "should set the Node cache class to :active_record" do
            Puppet::Node.expects(:cache_class=).with(:active_record)
            Puppet.settings[:storeconfigs] = true
        end
    end
end
