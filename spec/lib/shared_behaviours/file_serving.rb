#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

describe "Puppet::FileServing::Files", :shared => true do
    it "should use the rest terminus when the 'puppet' URI scheme is used and a host name is present" do
        uri = "puppet://myhost/mymod/my/file"
        @indirection.terminus(:rest).expects(:find).with(uri)
        @test_class.find(uri)
    end

    it "should use the rest terminus when the 'puppet' URI scheme is used, no host name is present, and the process name is not 'puppet'" do
        uri = "puppet:///mymod/my/file"
        Puppet.settings.stubs(:value).with(:name).returns("puppetd")
        Puppet.settings.stubs(:value).with(:modulepath).returns("")
        @indirection.terminus(:rest).expects(:find).with(uri)
        @test_class.find(uri)
    end

    it "should use the file_server terminus when the 'puppet' URI scheme is used, no host name is present, and the process name is 'puppet'" do
        uri = "puppet:///mymod/my/file"
        Puppet.settings.stubs(:value).with(:name).returns("puppet")
        Puppet.settings.stubs(:value).with(:modulepath).returns("")
        Puppet.settings.stubs(:value).with(:libdir).returns("")
        Puppet.settings.stubs(:value).with(:fileserverconfig).returns("/whatever")
        @indirection.terminus(:file_server).expects(:find).with(uri)
        @test_class.find(uri)
    end

    it "should use the file_server terminus when the 'puppetmounts' URI scheme is used" do
        uri = "puppetmounts:///mymod/my/file"
        @indirection.terminus(:file_server).expects(:find).with(uri)
        @test_class.find(uri)
    end

    it "should use the local terminus when the 'file' URI scheme is used" do
        uri = "file:///mymod/my/file"
        @indirection.terminus(:local).expects(:find).with(uri)
        @test_class.find(uri)
    end

    it "should use the local terminus when a fully qualified path is provided" do
        uri = "/mymod/my/file"
        @indirection.terminus(:local).expects(:find).with(uri)
        @test_class.find(uri)
    end
end

