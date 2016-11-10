#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/multi_file_setting'

describe Puppet::Settings::MultiFileSetting do
  MultiFileSetting = Puppet::Settings::MultiFileSetting

  include PuppetSpec::Files

  it "should be able to be converted into a resource" do
    expect(MultiFileSetting.new(:settings => mock("settings"), :desc => "eh")).to respond_to(:to_resource)
  end

  describe "when being converted to a resource" do
    before do
      @basepath1 = make_absolute("/somepath")
      @basepath2 = make_absolute("/otherpath")
      @settings = mock 'settings'
      @file = Puppet::Settings::MultiFileSetting.new(:settings => @settings, :desc => "eh", :name => :myfile, :section => "mysect")
      @file.stubs(:create_files?).returns true
      @settings.stubs(:value).with(:myfile, nil, false).returns [@basepath1, @basepath2]
    end

    it "should return :file as its type" do
      expect(@file.type).to eq(:file)
    end

    it "should skip non-existent files if 'create_files' is not enabled" do
      @file.expects(:create_files?).twice.returns false
      @file.expects(:type).returns :file
      Puppet::FileSystem.expects(:exist?).with(@basepath1).returns false
      Puppet::FileSystem.expects(:exist?).with(@basepath2).returns false
      expect(@file.to_resource).to be_empty
    end

    it "should manage existent files even if 'create_files' is not enabled" do
      @file.expects(:create_files?).twice.returns false
      @file.expects(:type).returns :file
      Puppet::FileSystem.stubs(:exist?)
      Puppet::FileSystem.expects(:exist?).with(@basepath1).returns true
      Puppet::FileSystem.expects(:exist?).with(@basepath2).returns true
      resources = @file.to_resource
      expect(resources).to be_instance_of(Array)
      expect(resources.size).to eq(2)
      expect(resources[0]).to be_instance_of(Puppet::Resource)
    end

    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should skip files in /dev" do
        @settings.stubs(:value).with(:myfile, nil, false).returns "/dev/file"
        expect(@file.to_resource).to be_nil
      end
    end

    it "should skip files whose paths are not strings" do
      @settings.stubs(:value).with(:myfile, nil, false).returns :foo
      expect(@file.to_resource).to be_nil
    end

    it "should return a file resource with the path set appropriately" do
      resources = @file.to_resource
      expect(resources[0].type).to eq("File")
      expect(resources[0].title).to eq(@basepath1)
      expect(resources[1].type).to eq("File")
      expect(resources[1].title).to eq(@basepath2)
    end

    it "should fully qualified returned files if necessary (#795)" do
      @settings.stubs(:value).with(:myfile, nil, false).returns ["myfile"]
      path = File.expand_path('myfile')
      expect(@file.to_resource.first.title).to eq(path)
    end

    it "should set the mode on the file if a mode is provided as an octal number" do
      @file.mode = 0755

      @file.to_resource.each {|resource| expect(resource[:mode]).to eq('755')}
    end

    it "should set the mode on the file if a mode is provided as a string" do
      @file.mode = '0755'

      @file.to_resource.each {|resource| expect(resource[:mode]).to eq('755')}
    end

    it "should not set the mode on a the file if manage_internal_file_permissions is disabled" do
      Puppet[:manage_internal_file_permissions] = false

      @file.stubs(:mode).returns(0755)

      @file.to_resource.each {|resource| expect(resource[:mode]).to eq(nil)}
    end

    it "should set the owner if running as root and the owner is provided" do
      Puppet.features.expects(:root?).twice.returns true
      Puppet.features.stubs(:microsoft_windows?).twice.returns false

      @file.stubs(:owner).returns "foo"
      @file.to_resource.each {|resource| expect(resource[:owner]).to eq("foo")}
    end

    it "should not set the owner if manage_internal_file_permissions is disabled" do
      Puppet[:manage_internal_file_permissions] = false
      Puppet.features.stubs(:root?).returns true
      @file.stubs(:owner).returns "foo"

      @file.to_resource.each {|resource| expect(resource[:owner]).to eq(nil)}
    end

    it "should set the group if running as root and the group is provided" do
      Puppet.features.expects(:root?).twice.returns true
      Puppet.features.stubs(:microsoft_windows?).twice.returns false

      @file.stubs(:group).returns "foo"
      @file.to_resource.each {|resource| expect(resource[:group]).to eq("foo")}
    end

    it "should not set the group if manage_internal_file_permissions is disabled" do
      Puppet[:manage_internal_file_permissions] = false
      Puppet.features.stubs(:root?).returns true
      @file.stubs(:group).returns "foo"

      @file.to_resource.each {|resource| expect(resource[:group]).to eq(nil)}
    end


    it "should not set owner if not running as root" do
      Puppet.features.expects(:root?).twice.returns false
      Puppet.features.stubs(:microsoft_windows?).returns false
      @file.stubs(:owner).returns "foo"
      @file.to_resource.each {|resource| expect(resource[:owner]).to be_nil}
    end

    it "should not set group if not running as root" do
      Puppet.features.expects(:root?).twice.returns false
      Puppet.features.stubs(:microsoft_windows?).returns false
      @file.stubs(:group).returns "foo"
      @file.to_resource.each {|resource| expect(resource[:group]).to be_nil}
    end

    describe "on Microsoft Windows systems" do
      before :each do
        Puppet.features.stubs(:microsoft_windows?).returns true
      end

      it "should not set owner" do
        @file.stubs(:owner).returns "foo"
        @file.to_resource.each {|resource| expect(resource[:owner]).to be_nil}
      end

      it "should not set group" do
        @file.stubs(:group).returns "foo"
        @file.to_resource.each {|resource| expect(resource[:group]).to be_nil}
      end
    end

    it "should set the loglevel to :debug" do
      @file.to_resource.each {|resource| expect(resource[:loglevel]).to eq(:debug)}
    end

    it "should set the backup to false" do
      @file.to_resource.each {|resource| expect(resource[:backup]).to be_falsey}
    end

    it "should tag the resource with the settings section" do
      @file.expects(:section).twice.returns "mysect"
      @file.to_resource.each {|resource| expect(resource).to be_tagged("mysect")}
    end

    it "should tag the resource with the setting name" do
      @file.to_resource.each {|resource| expect(resource).to be_tagged("myfile")}
    end

    it "should tag the resource with 'settings'" do
      @file.to_resource.each {|resource| expect(resource).to be_tagged("settings")}
    end

    it "should set links to 'follow'" do
      @file.to_resource.each {|resource| expect(resource[:links]).to eq(:follow)}
    end
  end

  describe "#munge" do
    it 'splits arguments using the platform-specific path separater' do
      filesetting = MultiFileSetting.new(:settings => mock("settings"), :desc => "eh")
      abs_path = Puppet.features.microsoft_windows? ? ['C:/path_a', 'C:/path_b'] : ['/path_a', '/path_b']
      expect(filesetting.munge("/path_a#{File::PATH_SEPARATOR}/path_b")).to eq(abs_path)
    end
  end

  context "when opening", :unless => Puppet.features.microsoft_windows? do
    let(:path) do
      tmpfile('file_setting_spec')
    end

    let(:setting) do
      settings = mock("settings", :value => [path])
      MultiFileSetting.new(:name => :mysetting, :desc => "creates a file", :settings => settings)
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
