#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/file_serving/mount'

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

    it "should fail if the path does not exist" do
        FileTest.expects(:exists?).returns(false)
        proc { @mount.path = @dir }.should raise_error(ArgumentError)
    end

    it "should fail if the path is not a directory" do
        FileTest.expects(:exists?).returns(true)
        FileTest.expects(:directory?).returns(false)
        proc { @mount.path = @dir }.should raise_error(ArgumentError)
    end

    it "should fail if the path is not readable" do
        FileTest.expects(:exists?).returns(true)
        FileTest.expects(:directory?).returns(true)
        FileTest.expects(:readable?).returns(false)
        proc { @mount.path = @dir }.should raise_error(ArgumentError)
    end
end

describe Puppet::FileServing::Mount, " when finding files" do
    before do
        FileTest.stubs(:exists?).returns(true)
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
        Facter.stubs(:value).with("hostname").returns("myhost")
        Facter.stubs(:value).with("domain").returns("mydomain.com")
        @mount.path = "/%h/%d/%H"
        @mount.path().should == "/myhost/mydomain.com/myhost.mydomain.com"
    end

    it "should ignore links by default"

    it "should follow links when asked"
end

describe Puppet::FileServing::Mount, " when providing metadata" do
    before do
        FileTest.stubs(:exists?).returns(true)
        FileTest.stubs(:directory?).returns(true)
        FileTest.stubs(:readable?).returns(true)
        @mount = Puppet::FileServing::Mount.new("test", "/mount")
        @host = "host.domain.com"
    end

    it "should return nil if the file is absent" do
        Puppet::FileServing::Metadata.expects(:new).never
        FileTest.stubs(:exists?).returns(false)
        @mount.metadata("/my/path").should be_nil
    end

    it "should return a Metadata instance if the file is present" do
        Puppet::FileServing::Metadata.expects(:new).returns(:myobj)
        @mount.metadata("/my/path").should == :myobj
    end
end

describe Puppet::FileServing::Mount, " when providing content" do
    before do
        FileTest.stubs(:exists?).returns(true)
        FileTest.stubs(:directory?).returns(true)
        FileTest.stubs(:readable?).returns(true)
        @mount = Puppet::FileServing::Mount.new("test", "/mount")
        @host = "host.domain.com"
    end

    it "should return nil if the file is absent" do
        Puppet::FileServing::Content.expects(:new).never
        FileTest.stubs(:exists?).returns(false)
        @mount.content("/my/path").should be_nil
    end

    it "should return a Content instance if the file is present" do
        Puppet::FileServing::Content.expects(:new).returns(:myobj)
        @mount.content("/my/path").should == :myobj
    end
end
