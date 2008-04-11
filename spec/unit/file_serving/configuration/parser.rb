#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/file_serving/configuration/parser'

describe Puppet::FileServing::Configuration::Parser do
    it "should subclass the LoadedFile class" do
        Puppet::FileServing::Configuration::Parser.superclass.should equal(Puppet::Util::LoadedFile)
    end
end


module FSConfigurationParserTesting
    def mock_file_content(content)
        # We want an array, but we actually want our carriage returns on all of it.
        lines = content.split("\n").collect { |l| l + "\n" }
        @filehandle.stubs(:each).multiple_yields(*lines)
    end
end

describe Puppet::FileServing::Configuration::Parser do
    before :each do
        @path = "/my/config.conf"
        FileTest.stubs(:exists?).with(@path).returns(true)
        FileTest.stubs(:readable?).with(@path).returns(true)
        @filehandle = mock 'filehandle'
        File.expects(:open).with(@path).yields(@filehandle)
        @parser = Puppet::FileServing::Configuration::Parser.new(@path)
    end

    describe Puppet::FileServing::Configuration::Parser, " when parsing" do
        include FSConfigurationParserTesting

        before do
            @parser.stubs(:add_modules_mount)
        end

        it "should allow comments" do
            @filehandle.expects(:each).yields("# this is a comment\n")
            proc { @parser.parse }.should_not raise_error
        end

        it "should allow blank lines" do
            @filehandle.expects(:each).yields("\n")
            proc { @parser.parse }.should_not raise_error
        end

        it "should create a new mount for each section in the configuration" do
            mount1 = mock 'one'
            mount2 = mock 'two'
            Puppet::FileServing::Mount.expects(:new).with("one").returns(mount1)
            Puppet::FileServing::Mount.expects(:new).with("two").returns(mount2)
            mock_file_content "[one]\n[two]\n"
            @parser.parse
        end

        # This test is almost the exact same as the previous one.
        it "should return a hash of the created mounts" do
            mount1 = mock 'one'
            mount2 = mock 'two'
            Puppet::FileServing::Mount.expects(:new).with("one").returns(mount1)
            Puppet::FileServing::Mount.expects(:new).with("two").returns(mount2)
            mock_file_content "[one]\n[two]\n"

            @parser.parse.should == {"one" => mount1, "two" => mount2}
        end

        it "should only allow mount names that are alphanumeric plus dashes" do
            mock_file_content "[a*b]\n"
            proc { @parser.parse }.should raise_error(ArgumentError)
        end

        it "should fail if the value for path/allow/deny starts with an equals sign" do
            mock_file_content "[one]\npath = /testing"
            proc { @parser.parse }.should raise_error(ArgumentError)
        end
    end

    describe Puppet::FileServing::Configuration::Parser, " when parsing mount attributes" do
        include FSConfigurationParserTesting

        before do
            @mount = stub 'mount', :name => "one"
            Puppet::FileServing::Mount.expects(:new).with("one").returns(@mount)
            @parser.stubs(:add_modules_mount)
        end

        it "should set the mount path to the path attribute from that section" do
            mock_file_content "[one]\npath /some/path\n"

            @mount.expects(:path=).with("/some/path")
            @parser.parse
        end

        it "should tell the mount to allow any allow values from the section" do
            mock_file_content "[one]\nallow something\n"

            @mount.expects(:info)
            @mount.expects(:allow).with("something")
            @parser.parse
        end

        it "should tell the mount to deny any deny values from the section" do
            mock_file_content "[one]\ndeny something\n"

            @mount.expects(:info)
            @mount.expects(:deny).with("something")
            @parser.parse
        end

        it "should fail on any attributes other than path, allow, and deny" do
            mock_file_content "[one]\ndo something\n"

            proc { @parser.parse }.should raise_error(ArgumentError)
        end
    end

    describe Puppet::FileServing::Configuration::Parser, " when parsing the modules mount" do
        include FSConfigurationParserTesting

        before do
            @mount = stub 'mount', :name => "modules"
            Puppet::FileServing::Mount.expects(:new).with("modules").returns(@mount)
        end

        it "should warn if a path is set" do
            mock_file_content "[modules]\npath /some/path\n"

            @modules.expects(:path=).never
            Puppet.expects(:warning)
            @parser.parse
        end
    end
end
