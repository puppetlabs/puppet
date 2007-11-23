#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-25.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../../spec_helper'

require 'puppet/provider/interface/sunos'


provider_class = Puppet::Type.type(:interface).provider(:sunos)

describe provider_class do
    it "should not be functional on non-SunOS kernels" do
        Facter.expects(:value).with(:kernel).returns("Linux")
        provider_class.should_not be_suitable
    end

    it "should be functional on SunOS kernels" do
        Facter.expects(:value).with(:kernel).returns("SunOS")
        provider_class.should be_suitable
    end

    it "should be a subclass of ParsedFile" do
        provider_class.superclass.should equal(Puppet::Provider::ParsedFile)
    end

    it "should use /etc/hostname.lo0 as the default target" do
        provider_class.default_target.should == "/etc/hostname.lo0"
    end

    it "should use the :flat filetype" do
        provider_class.filetype.name.should == :flat
    end

    it "should return an instance for every file matching /etc/hostname.*" do
        Dir.expects(:glob).with("/etc/hostname.*").returns(%w{one two})
        one_record = mock 'one_record'
        two_record = mock 'two_record'
        provider_class.expects(:parse).with("one").returns([one_record])
        provider_class.expects(:parse).with("two").returns([two_record])
        one_instance = mock 'one_instance'
        two_instance = mock 'two_instance'
        provider_class.expects(:new).with(one_record).returns(one_instance)
        provider_class.expects(:new).with(two_record).returns(two_instance)

        provider_class.instances.should == [one_instance, two_instance]
    end
end

describe provider_class, " when parsing" do
    it "should mark the interface as present" do
        provider_class.parse("testing")[0][:ensure].should == :present
    end

    it "should mark the interface as an alias if the first word is 'addif'" do
        provider_class.parse("addif testing")[0][:interface_type].should == :alias
    end

    it "should not mark the interface as normal if the first word is not 'addif'" do
        provider_class.parse("testing")[0][:interface_type].should == :normal
    end

    it "should start the interface on boot of the last word is 'up'" do
        provider_class.parse("testing up")[0][:onboot].should == :true
    end

    it "should not start the interface on boot of the last word is not 'up'" do
        provider_class.parse("testing")[0][:onboot].should == :false
    end

    it "should set the interface to the first non-behavioural word" do
        provider_class.parse("addif testing up")[0][:name].should == "testing"
    end

    it "should consider any remaining terms to be interface options" do
        provider_class.parse("addif testing -O up")[0][:ifopts].should == "-O"
    end

    it "should pick its file path by combining '/etc/hostname.' with the resource's interface" do
        provider = provider_class.new(:record_type => :sunos, :interface_type => :normal, :name => "testing")
        resource = stub 'resource'
        resource.stubs(:[]).with(:interface).returns("eth0")
        provider.resource = resource
        provider.file_path.should == "/etc/hostname.eth0"
    end
end

describe provider_class, " when generating" do
    it "should prefix the text with 'addif' if the interface is an alias" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :alias, :name => "testing"}]).should =~ /^addif /
    end

    it "should not prefix the text with 'addif' if the interface is not an alias" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :normal, :name => "testing"}]).should !~ /^testing/
    end

    it "should put the name first if the interface is not an alias" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :normal, :name => "testing"}]).should =~ /^testing/
    end

    it "should put the name after the 'addif' if the interface is an alias" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :alias, :name => "testing"}]).should =~ /^addif testing/
    end

    it "should put the ifopts after the name if they are present" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :normal, :ifopts => "-O", :name => "testing"}]).should =~ /testing -O/
    end

    it "should not put the ifopts after the name if they are marked :absent" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :normal, :ifopts => :absent, :name => "testing"}]).should == "testing\n"
    end

    it "should mark the interface up if onboot is enabled" do
        provider_class.to_file([{:record_type => :sunos, :onboot => :true, :interface_type => :normal, :name => "testing"}]).should == "testing up\n"
    end

    it "should not include a commented header" do
        provider_class.to_file([{:record_type => :sunos, :interface_type => :normal, :name => "testing"}]).should == "testing\n"
    end
end
