#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/settings'
require 'puppet/util/settings/file_setting'

describe Puppet::Util::Settings::FileSetting do
  FileSetting = Puppet::Util::Settings::FileSetting

  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/somepath")
  end

  describe "when determining whether the service user should be used" do
    before do
      @settings = mock 'settings'
      @settings.stubs(:[]).with(:mkusers).returns false
      @settings.stubs(:service_user_available?).returns true
    end

    it "should be true if the service user is available" do
      @settings.expects(:service_user_available?).returns true
      setting = FileSetting.new(:settings => @settings, :owner => "root", :desc => "a setting")
      setting.should be_use_service_user
    end

    it "should be true if 'mkusers' is set" do
      @settings.expects(:[]).with(:mkusers).returns true
      setting = FileSetting.new(:settings => @settings, :owner => "root", :desc => "a setting")
      setting.should be_use_service_user
    end

    it "should be false if the service user is not available and 'mkusers' is unset" do
      setting = FileSetting.new(:settings => @settings, :owner => "root", :desc => "a setting")
      setting.should be_use_service_user
    end
  end

  describe "when setting the owner" do
    it "should allow the file to be owned by root" do
      root_owner = lambda { FileSetting.new(:settings => mock("settings"), :owner => "root", :desc => "a setting") }
      root_owner.should_not raise_error
    end

    it "should allow the file to be owned by the service user" do
      service_owner = lambda { FileSetting.new(:settings => mock("settings"), :owner => "service", :desc => "a setting") }
      service_owner.should_not raise_error
    end

    it "should allow the ownership of the file to be unspecified" do
      no_owner = lambda { FileSetting.new(:settings => mock("settings"), :desc => "a setting") }
      no_owner.should_not raise_error
    end

    it "should not allow other owners" do
      invalid_owner = lambda { FileSetting.new(:settings => mock("settings"), :owner => "invalid", :desc => "a setting") }
      invalid_owner.should raise_error(FileSetting::SettingError)
    end
  end

  describe "when reading the owner" do
    it "should be root when the setting specifies root" do
      setting = FileSetting.new(:settings => mock("settings"), :owner => "root", :desc => "a setting")
      setting.owner.should == "root"
    end

    it "should be the owner of the service when the setting specifies service and the service user should be used" do
      settings = mock("settings")
      settings.stubs(:[]).returns "the_service"

      setting = FileSetting.new(:settings => settings, :owner => "service", :desc => "a setting")
      setting.expects(:use_service_user?).returns true
      setting.owner.should == "the_service"
    end

    it "should be the root when the setting specifies service and the service user should not be used" do
      settings = mock("settings")
      settings.stubs(:[]).returns "the_service"

      setting = FileSetting.new(:settings => settings, :owner => "service", :desc => "a setting")
      setting.expects(:use_service_user?).returns false
      setting.owner.should == "root"
    end

    it "should be nil when the owner is unspecified" do
      FileSetting.new(:settings => mock("settings"), :desc => "a setting").owner.should be_nil
    end
  end

  describe "when setting the group" do
    it "should allow the group to be service" do
      service_group = lambda { FileSetting.new(:settings => mock("settings"), :group => "service", :desc => "a setting") }
      service_group.should_not raise_error
    end

    it "should allow the group to be unspecified" do
      no_group = lambda { FileSetting.new(:settings => mock("settings"), :desc => "a setting") }
      no_group.should_not raise_error
    end

    it "should not allow invalid groups" do
      invalid_group = lambda { FileSetting.new(:settings => mock("settings"), :group => "invalid", :desc => "a setting") }
      invalid_group.should raise_error(FileSetting::SettingError)
    end
  end

  describe "when reading the group" do
    it "should be service when the setting specifies service" do
      setting = FileSetting.new(:settings => mock("settings", :[] => "the_service"), :group => "service", :desc => "a setting")
      setting.group.should == "the_service"
    end

    it "should be nil when the group is unspecified" do
      FileSetting.new(:settings => mock("settings"), :desc => "a setting").group.should be_nil
    end
  end

  it "should be able to be converted into a resource" do
    FileSetting.new(:settings => mock("settings"), :desc => "eh").should respond_to(:to_resource)
  end

  describe "when being converted to a resource" do
    before do
      @settings = mock 'settings'
      @file = Puppet::Util::Settings::FileSetting.new(:settings => @settings, :desc => "eh", :name => :mydir, :section => "mysect")
      @settings.stubs(:value).with(:mydir).returns @basepath
    end

    it "should skip files that cannot determine their types" do
      @file.expects(:type).returns nil
      @file.to_resource.should be_nil
    end

    it "should skip non-existent files if 'create_files' is not enabled" do
      @file.expects(:create_files?).returns false
      @file.expects(:type).returns :file
      File.expects(:exist?).with(@basepath).returns false
      @file.to_resource.should be_nil
    end

    it "should manage existent files even if 'create_files' is not enabled" do
      @file.expects(:create_files?).returns false
      @file.expects(:type).returns :file
      File.expects(:exist?).with(@basepath).returns true
      @file.to_resource.should be_instance_of(Puppet::Resource)
    end

    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should skip files in /dev" do
        @settings.stubs(:value).with(:mydir).returns "/dev/file"
        @file.to_resource.should be_nil
      end
    end

    it "should skip files whose paths are not strings" do
      @settings.stubs(:value).with(:mydir).returns :foo
      @file.to_resource.should be_nil
    end

    it "should return a file resource with the path set appropriately" do
      resource = @file.to_resource
      resource.type.should == "File"
      resource.title.should == @basepath
    end

    it "should fully qualified returned files if necessary (#795)" do
      @settings.stubs(:value).with(:mydir).returns "myfile"
      path = File.join(Dir.getwd, "myfile")
      # Dir.getwd can return windows paths with backslashes, so we normalize them using expand_path
      path = File.expand_path(path) if Puppet.features.microsoft_windows?
      @file.to_resource.title.should == path
    end

    it "should set the mode on the file if a mode is provided" do
      @file.mode = 0755

      @file.to_resource[:mode].should == 0755
    end

    it "should not set the mode on a the file if manage_internal_file_permissions is disabled" do
      Puppet[:manage_internal_file_permissions] = false

      @file.stubs(:mode).returns(0755)

      @file.to_resource[:mode].should == nil
    end

    it "should set the owner if running as root and the owner is provided" do
      Puppet.features.expects(:root?).returns true
      Puppet.features.stubs(:microsoft_windows?).returns false

      @file.stubs(:owner).returns "foo"
      @file.to_resource[:owner].should == "foo"
    end

    it "should not set the owner if manage_internal_file_permissions is disabled" do
      Puppet[:manage_internal_file_permissions] = false
      Puppet.features.stubs(:root?).returns true
      @file.stubs(:owner).returns "foo"

      @file.to_resource[:owner].should == nil
    end

    it "should set the group if running as root and the group is provided" do
      Puppet.features.expects(:root?).returns true
      Puppet.features.stubs(:microsoft_windows?).returns false

      @file.stubs(:group).returns "foo"
      @file.to_resource[:group].should == "foo"
    end

    it "should not set the group if manage_internal_file_permissions is disabled" do
      Puppet[:manage_internal_file_permissions] = false
      Puppet.features.stubs(:root?).returns true
      @file.stubs(:group).returns "foo"

      @file.to_resource[:group].should == nil
    end


    it "should not set owner if not running as root" do
      Puppet.features.expects(:root?).returns false
      Puppet.features.stubs(:microsoft_windows?).returns false
      @file.stubs(:owner).returns "foo"
      @file.to_resource[:owner].should be_nil
    end

    it "should not set group if not running as root" do
      Puppet.features.expects(:root?).returns false
      Puppet.features.stubs(:microsoft_windows?).returns false
      @file.stubs(:group).returns "foo"
      @file.to_resource[:group].should be_nil
    end

    describe "on Microsoft Windows systems" do
      before :each do
        Puppet.features.stubs(:microsoft_windows?).returns true
      end

      it "should not set owner" do
        @file.stubs(:owner).returns "foo"
        @file.to_resource[:owner].should be_nil
      end

      it "should not set group" do
        @file.stubs(:group).returns "foo"
        @file.to_resource[:group].should be_nil
      end
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

    it "should set links to 'follow'" do
      @file.to_resource[:links].should == :follow
    end
  end
end

