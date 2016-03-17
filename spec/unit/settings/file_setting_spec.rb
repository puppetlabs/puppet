#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/file_setting'

describe Puppet::Settings::FileSetting do
  FileSetting = Puppet::Settings::FileSetting

  include PuppetSpec::Files

  describe "when controlling permissions" do
    def settings(wanted_values = {})
       real_values = {
        :user => 'root',
        :group => 'root',
        :mkusers => false,
        :service_user_available? => false,
        :service_group_available? => false
      }.merge(wanted_values)

      settings = mock("settings")

      settings.stubs(:[]).with(:user).returns real_values[:user]
      settings.stubs(:[]).with(:group).returns real_values[:group]
      settings.stubs(:[]).with(:mkusers).returns real_values[:mkusers]
      settings.stubs(:service_user_available?).returns real_values[:service_user_available?]
      settings.stubs(:service_group_available?).returns real_values[:service_group_available?]

      settings
    end

    context "owner" do
      it "can always be root" do
        settings = settings(:user => "the_service", :mkusers => true)

        setting = FileSetting.new(:settings => settings, :owner => "root", :desc => "a setting")

        setting.owner.should == "root"
      end

      it "is the service user if we are making users" do
        settings = settings(:user => "the_service", :mkusers => true, :service_user_available? => false)

        setting = FileSetting.new(:settings => settings, :owner => "service", :desc => "a setting")

        setting.owner.should == "the_service"
      end

      it "is the service user if the user is available on the system" do
        settings = settings(:user => "the_service", :mkusers => false, :service_user_available? => true)

        setting = FileSetting.new(:settings => settings, :owner => "service", :desc => "a setting")

        setting.owner.should == "the_service"
      end

      it "is root when the setting specifies service and the user is not available on the system" do
        settings = settings(:user => "the_service", :mkusers => false, :service_user_available? => false)

        setting = FileSetting.new(:settings => settings, :owner => "service", :desc => "a setting")

        setting.owner.should == "root"
      end

      it "is unspecified when no specific owner is wanted" do
        FileSetting.new(:settings => settings(), :desc => "a setting").owner.should be_nil
      end

      it "does not allow other owners" do
        expect { FileSetting.new(:settings => settings(), :desc => "a setting", :name => "testing", :default => "the default", :owner => "invalid") }.
          to raise_error(FileSetting::SettingError, /The :owner parameter for the setting 'testing' must be either 'root' or 'service'/)
      end
    end

    context "group" do
      it "is unspecified when no specific group is wanted" do
        setting = FileSetting.new(:settings => settings(), :desc => "a setting")

        setting.group.should be_nil
      end

      it "is root if root is requested" do
        settings = settings(:group => "the_group")

        setting = FileSetting.new(:settings => settings, :group => "root", :desc => "a setting")

        setting.group.should == "root"
      end

      it "is the service group if we are making users" do
        settings = settings(:group => "the_service", :mkusers => true)

        setting = FileSetting.new(:settings => settings, :group => "service", :desc => "a setting")

        setting.group.should == "the_service"
      end

      it "is the service user if the group is available on the system" do
        settings = settings(:group => "the_service", :mkusers => false, :service_group_available? => true)

        setting = FileSetting.new(:settings => settings, :group => "service", :desc => "a setting")

        setting.group.should == "the_service"
      end

      it "is unspecified when the setting specifies service and the group is not available on the system" do
        settings = settings(:group => "the_service", :mkusers => false, :service_group_available? => false)

        setting = FileSetting.new(:settings => settings, :group => "service", :desc => "a setting")

        setting.group.should be_nil
      end

      it "does not allow other groups" do
        expect { FileSetting.new(:settings => settings(), :group => "invalid", :name => 'testing', :desc => "a setting") }.
          to raise_error(FileSetting::SettingError, /The :group parameter for the setting 'testing' must be either 'root' or 'service'/)
      end
    end
  end

  it "should be able to be converted into a resource" do
    FileSetting.new(:settings => mock("settings"), :desc => "eh").should respond_to(:to_resource)
  end

  describe "when being converted to a resource" do
    before do
      @basepath = make_absolute("/somepath")
      @settings = mock 'settings'
      @file = Puppet::Settings::FileSetting.new(:settings => @settings, :desc => "eh", :name => :myfile, :section => "mysect")
      @file.stubs(:create_files?).returns true
      @settings.stubs(:value).with(:myfile, nil, false).returns @basepath
    end

    it "should return :file as its type" do
      @file.type.should == :file
    end

    it "should skip non-existent files if 'create_files' is not enabled" do
      @file.expects(:create_files?).returns false
      @file.expects(:type).returns :file
      Puppet::FileSystem.expects(:exist?).with(@basepath).returns false
      @file.to_resource.should be_nil
    end

    it "should manage existent files even if 'create_files' is not enabled" do
      @file.expects(:create_files?).returns false
      @file.expects(:type).returns :file
      Puppet::FileSystem.stubs(:exist?)
      Puppet::FileSystem.expects(:exist?).with(@basepath).returns true
      @file.to_resource.should be_instance_of(Puppet::Resource)
    end

    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should skip files in /dev" do
        @settings.stubs(:value).with(:myfile, nil, false).returns "/dev/file"
        @file.to_resource.should be_nil
      end
    end

    it "should skip files whose paths are not strings" do
      @settings.stubs(:value).with(:myfile, nil, false).returns :foo
      @file.to_resource.should be_nil
    end

    it "should return a file resource with the path set appropriately" do
      resource = @file.to_resource
      resource.type.should == "File"
      resource.title.should == @basepath
    end

    it "should fully qualified returned files if necessary (#795)" do
      @settings.stubs(:value).with(:myfile, nil, false).returns "myfile"
      path = File.expand_path('myfile')
      @file.to_resource.title.should == path
    end

    it "should set the mode on the file if a mode is provided as an octal number" do
      @file.mode = 0755

      @file.to_resource[:mode].should == '755'
    end

    it "should set the mode on the file if a mode is provided as a string" do
      @file.mode = '0755'

      @file.to_resource[:mode].should == '755'
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
      @file.to_resource.should be_tagged("myfile")
    end

    it "should tag the resource with 'settings'" do
      @file.to_resource.should be_tagged("settings")
    end

    it "should set links to 'follow'" do
      @file.to_resource[:links].should == :follow
    end
  end

  describe "#munge" do
    it 'does not expand the path of the special value :memory: so we can set dblocation to an in-memory database' do
      filesetting = FileSetting.new(:settings => mock("settings"), :desc => "eh")
      filesetting.munge(':memory:').should == ':memory:'
    end
  end

  context "when opening", :unless => Puppet.features.microsoft_windows? do
    let(:path) do
      tmpfile('file_setting_spec')
    end

    let(:setting) do
      settings = mock("settings", :value => path)
      FileSetting.new(:name => :mysetting, :desc => "creates a file", :settings => settings)
    end

    it "creates a file with mode 0640" do
      setting.mode = '0640'

      expect(File).to_not be_exist(path)
      setting.open('w')

      expect(File).to be_exist(path)
      expect(Puppet::FileSystem.stat(path).mode & 0777).to eq(0640)
    end

    it "preserves the mode of an existing file" do
      setting.mode = '0640'

      Puppet::FileSystem.touch(path)
      Puppet::FileSystem.chmod(0644, path)
      setting.open('w')

      expect(Puppet::FileSystem.stat(path).mode & 0777).to eq(0644)
    end
  end
end
