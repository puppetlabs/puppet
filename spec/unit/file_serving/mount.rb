#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/file_serving/mount'

module FileServingMountTesting
    def stub_facter(hostname)
        Facter.stubs(:value).with("hostname").returns(hostname.sub(/\..+/, ''))
        Facter.stubs(:value).with("domain").returns(hostname.sub(/^[^.]+\./, ''))
    end
end

describe Puppet::FileServing::Mount do
    it "should provide a method for clearing its cached host information" do
        old = Puppet::FileServing::Mount.localmap
        Puppet::Util::Cacher.invalidate
        Puppet::FileServing::Mount.localmap.should_not equal(old)
    end
end

describe Puppet::FileServing::Mount, " when initializing" do
    it "should fail on non-alphanumeric name" do
        proc { Puppet::FileServing::Mount.new("non alpha") }.should raise_error(ArgumentError)
    end

    it "should allow dashes in its name" do
        Puppet::FileServing::Mount.new("non-alpha").name.should == "non-alpha"
    end

    it "should allow an optional path" do
        Puppet::FileServing::Mount.new("name", "/").path.should == "/"
    end
end

describe Puppet::FileServing::Mount, " when setting the path" do
    before do
        @mount = Puppet::FileServing::Mount.new("test")
        @dir = "/this/path/does/not/exist"
    end

    it "should fail if the path is not a directory" do
        FileTest.expects(:directory?).returns(false)
        proc { @mount.path = @dir }.should raise_error(ArgumentError)
    end

    it "should fail if the path is not readable" do
        FileTest.expects(:directory?).returns(true)
        FileTest.expects(:readable?).returns(false)
        proc { @mount.path = @dir }.should raise_error(ArgumentError)
    end
end

describe Puppet::FileServing::Mount, " when finding files" do
    include FileServingMountTesting

    before do
        FileTest.stubs(:directory?).returns(true)
        FileTest.stubs(:readable?).returns(true)
        @mount = Puppet::FileServing::Mount.new("test")
        @host = "host.domain.com"
    end

    it "should fail if the mount path has not been set" do
        proc { @mount.file_path("/blah") }.should raise_error(ArgumentError)
    end

    it "should replace incidences of %h in the path with the client's short name" do
        @mount.path = "/dir/%h/yay"
        @mount.path(@host).should == "/dir/host/yay"
    end

    it "should replace incidences of %H in the path with the client's fully qualified name" do
        @mount.path = "/dir/%H/yay"
        @mount.path(@host).should == "/dir/host.domain.com/yay"
    end

    it "should replace incidences of %d in the path with the client's domain name" do
        @mount.path = "/dir/%d/yay"
        @mount.path(@host).should == "/dir/domain.com/yay"
    end

    it "should perform all necessary replacements" do
        @mount.path = "/%h/%d/%H"
        @mount.path(@host).should == "/host/domain.com/host.domain.com"
    end

    it "should perform replacements on the base path" do
        @mount.path = "/blah/%h"
        @mount.file_path("/my/stuff", @host).should == "/blah/host/my/stuff"
    end

    it "should not perform replacements on the per-file path" do
        @mount.path = "/blah"
        @mount.file_path("/%h/stuff", @host).should == "/blah/%h/stuff"
    end

    it "should look for files relative to its base directory" do
        @mount.path = "/blah"
        @mount.file_path("/my/stuff", @host).should == "/blah/my/stuff"
    end

    it "should use local host information if no client data is provided" do
        stub_facter("myhost.mydomain.com")
        @mount.path = "/%h/%d/%H"
        @mount.path().should == "/myhost/mydomain.com/myhost.mydomain.com"
    end

    after do
        Puppet::Util::Cacher.invalidate
    end
end

describe Puppet::FileServing::Mount, " when providing file paths" do
    include FileServingMountTesting

    before do
        FileTest.stubs(:exists?).returns(true)
        FileTest.stubs(:directory?).returns(true)
        FileTest.stubs(:readable?).returns(true)
        @mount = Puppet::FileServing::Mount.new("test", "/mount/%h")
        stub_facter("myhost.mydomain.com")
        @host = "host.domain.com"
    end

    it "should return nil if the file is absent" do
        FileTest.stubs(:exists?).returns(false)
        @mount.file("/my/path").should be_nil
    end

    it "should return the file path if the file is absent" do
        FileTest.stubs(:exists?).with("/my/path").returns(true)
        @mount.file("/my/path").should == "/mount/myhost/my/path"
    end

    it "should treat a nil file name as the path to the mount itself" do
        FileTest.stubs(:exists?).returns(true)
        @mount.file(nil).should == "/mount/myhost"
    end

    it "should use the client host name if provided in the options" do
        @mount.file("/my/path", :node => @host).should == "/mount/host/my/path"
    end
end
