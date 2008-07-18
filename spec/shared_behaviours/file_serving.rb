#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

describe "Puppet::FileServing::Files", :shared => true do
    it "should use the rest terminus when the 'puppet' URI scheme is used and a host name is present" do
        uri = "puppet://myhost/fakemod/my/file"
        @indirection.terminus(:rest).expects(:find)
        @test_class.find(uri)
    end

    it "should use the rest terminus when the 'puppet' URI scheme is used, no host name is present, and the process name is not 'puppet'" do
        uri = "puppet:///fakemod/my/file"
        Puppet.settings.stubs(:value).with(:name).returns("puppetd")
        Puppet.settings.stubs(:value).with(:modulepath).returns("")
        @indirection.terminus(:rest).expects(:find)
        @test_class.find(uri)
    end

    it "should use the file_server terminus when the 'puppet' URI scheme is used, no host name is present, and the process name is 'puppet'" do
        uri = "puppet:///fakemod/my/file"
        Puppet::Node::Environment.stubs(:new).returns(stub("env", :name => "testing"))
        Puppet.settings.stubs(:value).with(:name).returns("puppet")
        Puppet.settings.stubs(:value).with(:modulepath, "testing").returns("")
        Puppet.settings.stubs(:value).with(:modulepath).returns("")
        Puppet.settings.stubs(:value).with(:libdir).returns("")
        Puppet.settings.stubs(:value).with(:fileserverconfig).returns("/whatever")
        Puppet.settings.stubs(:value).with(:environment).returns("")
        @indirection.terminus(:file_server).expects(:find)
        @indirection.terminus(:file_server).stubs(:authorized?).returns(true)
        @test_class.find(uri)
    end

    it "should use the file_server terminus when the 'puppetmounts' URI scheme is used" do
        uri = "puppetmounts:///fakemod/my/file"
        @indirection.terminus(:file_server).expects(:find)
        @indirection.terminus(:file_server).stubs(:authorized?).returns(true)
        @test_class.find(uri)
    end

    it "should use the file terminus when the 'file' URI scheme is used" do
        uri = "file:///fakemod/my/file"
        @indirection.terminus(:file).expects(:find)
        @test_class.find(uri)
    end

    it "should use the file terminus when a fully qualified path is provided" do
        uri = "/fakemod/my/file"
        @indirection.terminus(:file).expects(:find)
        @test_class.find(uri)
    end

    it "should use the configuration to test whether the request is allowed" do
        uri = "puppetmounts:///fakemod/my/file"
        config = mock 'configuration'
        @indirection.terminus(:file_server).stubs(:configuration).returns config

        @indirection.terminus(:file_server).expects(:find)
        config.expects(:authorized?).returns(true)
        @test_class.find(uri, :node => "foo", :ip => "bar")
    end
end

