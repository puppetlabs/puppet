#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-25.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

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

    it "should pick its file path by combining '/etc/hostname.' with the interface if one is set" do
        provider = provider_class.new(:record_type => :sunos, :interface_type => :normal, :name => "testing", :interface => 'eth0')
        provider.file_path.should == "/etc/hostname.eth0"
    end

    it "should pick its file path by combining '/etc/hostname.' with the resource's interface if one is not set in the provider" do
        provider = provider_class.new(:record_type => :sunos, :interface_type => :normal, :name => "testing")
        resource = mock 'resource'
        resource.stubs(:[]).with(:interface).returns("eth0")
        provider.resource = resource
        provider.file_path.should == "/etc/hostname.eth0"
    end

    it "should fail when picking its file path if there is no resource nor an interface set in the provider" do
        provider = provider_class.new(:record_type => :sunos, :interface_type => :normal, :name => "testing")
        proc { provider.file_path }.should raise_error(Puppet::Error)
    end
end

describe provider_class, " when listing interfaces" do
    it "should return an instance for every file matching /etc/hostname.*, created with the interface name set from the file" do
        Dir.expects(:glob).with("/etc/hostname.*").returns(%w{/etc/hostname.one /etc/hostname.two})
        one_instance = stub 'one_instance', :parse => nil
        two_instance = stub 'two_instance', :parse => nil
        provider_class.expects(:new).with(:interface => "one").returns(one_instance)
        provider_class.expects(:new).with(:interface => "two").returns(two_instance)

        provider_class.instances.should == [one_instance, two_instance]
    end

    it "should call parse on each instance being returned" do
        Dir.expects(:glob).with("/etc/hostname.*").returns(%w{/etc/hostname.one})
        one_instance = mock 'one_instance'
        provider_class.expects(:new).with(:interface => "one").returns(one_instance)

        one_instance.expects(:parse)

        provider_class.instances
    end

    it "should assign matching providers to any prefetched instances" do
        Dir.expects(:glob).with("/etc/hostname.*").returns(%w{one two})
        one_instance = stub 'one_instance', :name => "one", :parse => nil
        two_instance = stub 'two_instance', :name => "two", :parse => nil
        provider_class.expects(:new).with(:interface => "one").returns(one_instance)
        provider_class.expects(:new).with(:interface => "two").returns(two_instance)

        resources = {"one" => mock("one"), "three" => mock('three')}
        resources["one"].expects(:provider=).with(one_instance)

        provider_class.prefetch(resources)
    end
end

describe provider_class, " when creating and destroying" do
    before do
        @provider = provider_class.new(:interface => "eth0", :name => "testing")
    end

    it "should consider the interface present if the file exists" do
        FileTest.expects(:exist?).with("/etc/hostname.eth0").returns(true)
        @provider.should be_exists
    end

    it "should consider the interface absent if the file does not exist" do
        FileTest.expects(:exist?).with("/etc/hostname.eth0").returns(false)
        @provider.should_not be_exists
    end

    it "should remove the file if the interface is being destroyed" do
        File.expects(:unlink).with("/etc/hostname.eth0")
        @provider.destroy
    end

    it "should mark :ensure as :absent if the interface is destroyed" do
        File.stubs(:unlink)
        @provider.destroy
        @provider.ensure.should == :absent
    end

    it "should mark :ensure as :present if the interface is being created" do
        resource = stub 'resource', :name => 'testing'
        resource.stubs(:should).with { |name| name == :ensure }.returns(:present)
        resource.stubs(:should).with { |name| name != :ensure }.returns(nil)
        @provider.resource = resource
        @provider.create
        @provider.ensure.should == :present
    end

    it "should write the generated text to disk when the interface is flushed" do
        fh = mock("filehandle")
        File.expects(:open).yields(fh)
        fh.expects(:print).with("testing\n")
        resource = stub 'resource', :name => 'testing'
        resource.stubs(:should).with { |name| name == :ensure }.returns(:present)
        resource.stubs(:should).with { |name| name != :ensure }.returns(nil)
        @provider.resource = resource
        @provider.create
        @provider.flush
    end

    it "should not write the generated text to disk when the interface is flushed if :ensure == :absent" do
        @provider.ensure = :absent
        @provider.flush
    end
end

describe provider_class, " when parsing a non-existant file" do
    it "should mark the interface as absent" do
        @provider = provider_class.new(:interface => "eth0", :name => "testing")
        FileTest.expects(:exist?).with("/etc/hostname.eth0").returns(false)
        @provider.parse
        @provider.ensure.should == :absent
    end
end

describe provider_class, " when parsing an existing file" do
    before do
        @provider = provider_class.new(:interface => "eth0", :name => "testing")
        FileTest.stubs(:exist?).with("/etc/hostname.eth0").returns(true)
    end

    def set_text(text)
        File.stubs(:read).with("/etc/hostname.eth0").returns(text)
    end

    it "should retain the interface name" do
        set_text "testing"
        @provider.parse
        @provider.ensure.should == :present
        @provider.interface.should == "eth0"
    end

    it "should mark the interface as present" do
        set_text "testing"
        @provider.parse
        @provider.ensure.should == :present
    end

    it "should mark the interface as an alias if the first word is 'addif'" do
        set_text "addif testing"
        @provider.parse
        @provider.interface_type.should == :alias
    end

    it "should not mark the interface as normal if the first word is not 'addif'" do
        set_text "testing"
        @provider.parse
        @provider.interface_type.should == :normal
    end

    it "should start the interface on boot of the last word is 'up'" do
        set_text "testing up"
        @provider.parse
        @provider.onboot.should == :true
    end

    it "should not start the interface on boot of the last word is not 'up'" do
        set_text "testing"
        @provider.parse
        @provider.onboot.should == :false
    end

    it "should set the interface to the first non-behavioural word" do
        set_text "addif testing up"
        @provider.parse
        @provider.name.should == "testing"
    end

    it "should consider any remaining terms to be interface options" do
        set_text "addif testing -O up"
        @provider.parse
        @provider.ifopts.should == "-O"
    end
end

describe provider_class, " when generating" do
    before do
        @provider = provider_class.new(:interface => "eth0", :name => "testing")
    end

    it "should prefix the text with 'addif' if the interface is an alias" do
        @provider.interface_type = :alias
        @provider.generate.should == "addif testing"
    end

    it "should not prefix the text with 'addif' if the interface is not an alias" do
        @provider.generate.should == "testing"
    end

    it "should put the ifopts after the name if they are present" do
        @provider.ifopts = "-O"
        @provider.generate.should == "testing -O"
    end

    it "should mark the interface up if onboot is enabled" do
        @provider.onboot = :true
        @provider.generate.should == "testing up"
    end

    it "should use the resource name if no provider name is present" do
        provider = provider_class.new(:interface => "eth0")
        resource = stub 'resource', :name => "rtest"
        provider.resource = resource
        provider.generate.should == "rtest"
    end

    it "should use the provider name if present" do
        @provider.generate.should == "testing"
    end

    it "should fail if neither a resource nor the provider name is present" do
        provider = provider_class.new(:interface => "eth0")
        proc { provider.generate }.should raise_error
    end
end
