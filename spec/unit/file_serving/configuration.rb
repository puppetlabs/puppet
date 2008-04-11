#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/configuration'

describe Puppet::FileServing::Configuration do
    it "should make :new a private method" do
        proc { Puppet::FileServing::Configuration.new }.should raise_error
    end

    it "should return the same configuration each time :create is called" do
        Puppet::FileServing::Configuration.create.should equal(Puppet::FileServing::Configuration.create)
    end

    it "should have a method for removing the current configuration instance" do
        old = Puppet::FileServing::Configuration.create
        Puppet::FileServing::Configuration.clear_cache
        Puppet::FileServing::Configuration.create.should_not equal(old)
    end

    after do
        Puppet::FileServing::Configuration.clear_cache
    end
end

describe Puppet::FileServing::Configuration do

    before :each do
        @path = "/path/to/configuration/file.conf"
        Puppet.settings.stubs(:value).with(:fileserverconfig).returns(@path)
    end

    after :each do
        Puppet::FileServing::Configuration.clear_cache
    end

    describe Puppet::FileServing::Configuration, " when initializing" do

        it "should work without a configuration file" do
            FileTest.stubs(:exists?).with(@path).returns(false)
            proc { Puppet::FileServing::Configuration.create }.should_not raise_error
        end

        it "should parse the configuration file if present" do
            FileTest.stubs(:exists?).with(@path).returns(true)
            @parser = mock 'parser'
            @parser.expects(:parse).returns({})
            Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)
            Puppet::FileServing::Configuration.create
        end

        it "should determine the path to the configuration file from the Puppet settings" do
            Puppet::FileServing::Configuration.create
        end
    end

    describe Puppet::FileServing::Configuration, " when parsing the configuration file" do

        before do
            FileTest.stubs(:exists?).with(@path).returns(true)
            @parser = mock 'parser'
            Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)
        end

        it "should set the mount list to the results of parsing" do
            @parser.expects(:parse).returns("one" => mock("mount"))
            config = Puppet::FileServing::Configuration.create
            config.mounted?("one").should be_true
        end

        it "should not raise exceptions" do
            @parser.expects(:parse).raises(ArgumentError)
            proc { Puppet::FileServing::Configuration.create }.should_not raise_error
        end

        it "should replace the existing mount list with the results of reparsing" do
            @parser.expects(:parse).returns("one" => mock("mount"))
            config = Puppet::FileServing::Configuration.create
            config.mounted?("one").should be_true
            # Now parse again
            @parser.expects(:parse).returns("two" => mock('other'))
            config.send(:readconfig, false)
            config.mounted?("one").should be_false
            config.mounted?("two").should be_true
        end

        it "should not replace the mount list until the file is entirely parsed successfully" do
            @parser.expects(:parse).returns("one" => mock("mount"))
            @parser.expects(:parse).raises(ArgumentError)
            config = Puppet::FileServing::Configuration.create
            # Now parse again, so the exception gets thrown
            config.send(:readconfig, false)
            config.mounted?("one").should be_true
        end
    end

    describe Puppet::FileServing::Configuration, " when finding files" do

        before do
            @parser = mock 'parser'
            @parser.stubs(:changed?).returns true
            FileTest.stubs(:exists?).with(@path).returns(true)
            Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

            @mount1 = stub 'mount', :name => "one"
            @mounts = {"one" => @mount1}

            Facter.stubs(:value).with("hostname").returns("whatever")

            @config = Puppet::FileServing::Configuration.create
        end

        it "should fail if the uri does not match a leading slash followed by a valid mount name" do
            @parser.expects(:parse).returns(@mounts)
            proc { @config.file_path("something") }.should raise_error(ArgumentError)
        end

        it "should use the first term after the first slash for the mount name" do
            @parser.expects(:parse).returns(@mounts)
            FileTest.stubs(:exists?).returns(true)
            @mount1.expects(:file)
            @config.file_path("/one")
        end

        it "should use the remainder of the URI after the mount name as the file name" do
            @parser.expects(:parse).returns(@mounts)
            @mount1.expects(:file).with("something/else", {})
            FileTest.stubs(:exists?).returns(true)
            @config.file_path("/one/something/else")
        end

        it "should treat a bare name as a mount and no relative file" do
            @parser.expects(:parse).returns(@mounts)
            @mount1.expects(:file).with(nil, {})
            FileTest.stubs(:exists?).returns(true)
            @config.file_path("/one")
        end

        it "should treat a name with a trailing slash equivalently to a name with no trailing slash" do
            @parser.expects(:parse).returns(@mounts)
            @mount1.expects(:file).with(nil, {})
            FileTest.stubs(:exists?).returns(true)
            @config.file_path("/one/")
        end

        it "should return nil if the mount cannot be found" do
            @parser.expects(:changed?).returns(true)
            @parser.expects(:parse).returns({})
            @config.file_path("/one/something").should be_nil
        end

        it "should return nil if the mount does not contain the file" do
            @parser.expects(:parse).returns(@mounts)
            @mount1.expects(:file).with("something/else", {}).returns(nil)
            @config.file_path("/one/something/else").should be_nil
        end

        it "should return the fully qualified path if the mount exists" do
            @parser.expects(:parse).returns(@mounts)
            @mount1.expects(:file).with("something/else", {}).returns("/full/path")
            @config.file_path("/one/something/else").should == "/full/path"
        end

        it "should reparse the configuration file when it has changed" do
            @mount1.stubs(:file).returns("whatever")
            @parser.expects(:changed?).returns(true)
            @parser.expects(:parse).returns(@mounts)
            FileTest.stubs(:exists?).returns(true)
            @config.file_path("/one/something")

            @parser.expects(:changed?).returns(true)
            @parser.expects(:parse).returns({})
            @config.file_path("/one/something").should be_nil
        end
    end

    describe Puppet::FileServing::Configuration, " when checking authorization" do

        before do
            @parser = mock 'parser'
            @parser.stubs(:changed?).returns true
            FileTest.stubs(:exists?).with(@path).returns(true)
            Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

            @mount1 = stub 'mount', :name => "one"
            @mounts = {"one" => @mount1}
            @parser.stubs(:parse).returns(@mounts)

            Facter.stubs(:value).with("hostname").returns("whatever")

            @config = Puppet::FileServing::Configuration.create
        end

        it "should return false if the mount cannot be found" do
            @config.authorized?("/nope/my/file").should be_false
        end

        it "should use the mount to determine authorization" do
            @mount1.expects(:allowed?)
            @config.authorized?("/one/my/file")
        end

        it "should pass the client's name to the mount if provided" do
            @mount1.expects(:allowed?).with("myhost", nil)
            @config.authorized?("/one/my/file", :node => "myhost")
        end

        it "should pass the client's IP to the mount if provided" do
            @mount1.expects(:allowed?).with("myhost", "myip")
            @config.authorized?("/one/my/file", :node => "myhost", :ipaddress => "myip")
        end

        it "should return true if the mount allows the client" do
            @mount1.expects(:allowed?).returns(true)
            @config.authorized?("/one/my/file").should be_true
        end

        it "should return false if the mount denies the client"  do
            @mount1.expects(:allowed?).returns(false)
            @config.authorized?("/one/my/file").should be_false
        end
    end
end
