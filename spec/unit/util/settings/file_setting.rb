#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/util/settings'
require 'puppet/util/settings/file_setting'

describe Puppet::Util::Settings::FileSetting do
    it "should be able to be converted into a resource" do
        Puppet::Util::Settings::FileSetting.new(:settings => mock("settings"), :desc => "eh").should respond_to(:to_resource)
    end

    describe "when being converted to a resource" do
        before do
            @settings = mock 'settings'
            @file = Puppet::Util::Settings::FileSetting.new(:settings => @settings, :desc => "eh", :name => :mydir, :section => "mysect")
            @settings.stubs(:value).with(:mydir).returns "/my/file"
        end

        it "should skip files that cannot determine their types" do
            @file.expects(:type).returns nil
            @file.to_resource.should be_nil
        end

        it "should skip non-existent files if 'create_files' is not enabled" do
            @file.expects(:create_files?).returns false
            @file.expects(:type).returns :file
            File.expects(:exist?).with("/my/file").returns false
            @file.to_resource.should be_nil
        end

        it "should manage existent files even if 'create_files' is not enabled" do
            @file.expects(:create_files?).returns false
            @file.expects(:type).returns :file
            File.expects(:exist?).with("/my/file").returns true
            @file.to_resource.should be_instance_of(Puppet::Resource)
        end

        it "should skip files in /dev" do
            @settings.stubs(:value).with(:mydir).returns "/dev/file"
            @file.to_resource.should be_nil
        end

        it "should skip files whose paths are not strings" do
            @settings.stubs(:value).with(:mydir).returns :foo
            @file.to_resource.should be_nil
        end

        it "should return a file resource with the path set appropriately" do
            resource = @file.to_resource
            resource.type.should == "File"
            resource.title.should == "/my/file"
        end

        it "should fully qualified returned files if necessary (#795)" do
            @settings.stubs(:value).with(:mydir).returns "myfile"
            @file.to_resource.title.should == File.join(Dir.getwd, "myfile")
        end

        it "should set the mode on the file if a mode is provided" do
            @file.mode = 0755

            @file.to_resource[:mode].should == 0755
        end

        it "should set the owner if running as root and the owner is provided" do
            Puppet.features.expects(:root?).returns true
            @file.stubs(:owner).returns "foo"
            @file.to_resource[:owner].should == "foo"
        end

        it "should set the group if running as root and the group is provided" do
            Puppet.features.expects(:root?).returns true
            @file.stubs(:group).returns "foo"
            @file.to_resource[:group].should == "foo"
        end

        it "should not set owner if not running as root" do
            Puppet.features.expects(:root?).returns false
            @file.stubs(:owner).returns "foo"
            @file.to_resource[:owner].should be_nil
        end

        it "should not set group if not running as root" do
            Puppet.features.expects(:root?).returns false
            @file.stubs(:group).returns "foo"
            @file.to_resource[:group].should be_nil
        end

        it "should set :ensure to the file type" do
            @file.expects(:type).returns :directory
            @file.to_resource[:ensure].should == :directory
        end

        it "should set the loglevel to :debug" do
            @file.to_resource[:loglevel].should == :debug
        end

        it "should set the backup to false" do
            @file.to_resource[:backup].should be_false
        end

        it "should tag the resource with the settings section" do
            @file.expects(:section).returns "mysect"
            @file.to_resource.should be_tagged("mysect")
        end

        it "should tag the resource with the setting name" do
            @file.to_resource.should be_tagged("mydir")
        end

        it "should tag the resource with 'settings'" do
            @file.to_resource.should be_tagged("settings")
        end
    end
end

