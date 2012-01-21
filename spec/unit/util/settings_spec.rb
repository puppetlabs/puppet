#!/usr/bin/env rspec
require 'spec_helper'
require 'ostruct'

describe Puppet::Util::Settings do
  include PuppetSpec::Files

  describe "when specifying defaults" do
    before do
      @settings = Puppet::Util::Settings.new
    end

    it "should start with no defined parameters" do
      @settings.params.length.should == 0
    end

    it "should allow specification of default values associated with a section as an array" do
      @settings.setdefaults(:section, :myvalue => ["defaultval", "my description"])
    end

    it "should not allow duplicate parameter specifications" do
      @settings.setdefaults(:section, :myvalue => ["a", "b"])
      lambda { @settings.setdefaults(:section, :myvalue => ["c", "d"]) }.should raise_error(ArgumentError)
    end

    it "should allow specification of default values associated with a section as a hash" do
      @settings.setdefaults(:section, :myvalue => {:default => "defaultval", :desc => "my description"})
    end

    it "should consider defined parameters to be valid" do
      @settings.setdefaults(:section, :myvalue => ["defaultval", "my description"])
      @settings.valid?(:myvalue).should be_true
    end

    it "should require a description when defaults are specified with an array" do
      lambda { @settings.setdefaults(:section, :myvalue => ["a value"]) }.should raise_error(ArgumentError)
    end

    it "should require a description when defaults are specified with a hash" do
      lambda { @settings.setdefaults(:section, :myvalue => {:default => "a value"}) }.should raise_error(ArgumentError)
    end

    it "should raise an error if we can't guess the type" do
      lambda { @settings.setdefaults(:section, :myvalue => {:default => Object.new, :desc => "An impossible object"}) }.should raise_error(ArgumentError)
    end

    it "should support specifying owner, group, and mode when specifying files" do
      @settings.setdefaults(:section, :myvalue => {:default => "/some/file", :owner => "service", :mode => "boo", :group => "service", :desc => "whatever"})
    end

    it "should support specifying a short name" do
      @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
    end

    it "should support specifying the setting type" do
      @settings.setdefaults(:section, :myvalue => {:default => "/w", :desc => "b", :type => :setting})
      @settings.setting(:myvalue).should be_instance_of(Puppet::Util::Settings::Setting)
    end

    it "should fail if an invalid setting type is specified" do
      lambda { @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :type => :foo}) }.should raise_error(ArgumentError)
    end

    it "should fail when short names conflict" do
      @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
      lambda { @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"}) }.should raise_error(ArgumentError)
    end
  end

  describe "when setting values" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.setdefaults :main, :myval => ["val", "desc"]
      @settings.setdefaults :main, :bool => [true, "desc"]
    end

    it "should provide a method for setting values from other objects" do
      @settings[:myval] = "something else"
      @settings[:myval].should == "something else"
    end

    it "should support a getopt-specific mechanism for setting values" do
      @settings.handlearg("--myval", "newval")
      @settings[:myval].should == "newval"
    end

    it "should support a getopt-specific mechanism for turning booleans off" do
      @settings[:bool] = true
      @settings.handlearg("--no-bool", "")
      @settings[:bool].should == false
    end

    it "should support a getopt-specific mechanism for turning booleans on" do
      # Turn it off first
      @settings[:bool] = false
      @settings.handlearg("--bool", "")
      @settings[:bool].should == true
    end

    it "should consider a cli setting with no argument to be a boolean" do
      # Turn it off first
      @settings[:bool] = false
      @settings.handlearg("--bool")
      @settings[:bool].should == true
    end

    it "should consider a cli setting with an empty string as an argument to be a boolean, if the setting itself is a boolean" do
      # Turn it off first
      @settings[:bool] = false
      @settings.handlearg("--bool", "")
      @settings[:bool].should == true
    end

    it "should consider a cli setting with an empty string as an argument to be an empty argument, if the setting itself is not a boolean" do
      @settings[:myval] = "bob"
      @settings.handlearg("--myval", "")
      @settings[:myval].should == ""
    end

    it "should consider a cli setting with a boolean as an argument to be a boolean" do
      # Turn it off first
      @settings[:bool] = false
      @settings.handlearg("--bool", "true")
      @settings[:bool].should == true
    end

    it "should not consider a cli setting of a non boolean with a boolean as an argument to be a boolean" do
      # Turn it off first
      @settings[:myval] = "bob"
      @settings.handlearg("--no-myval", "")
      @settings[:myval].should == ""
    end

    it "should flag settings from the CLI" do
      @settings.handlearg("--myval")
      @settings.setting(:myval).setbycli.should be_true
    end

    it "should not flag settings memory" do
      @settings[:myval] = "12"
      @settings.setting(:myval).setbycli.should be_false
    end

    it "should clear the cache when setting getopt-specific values" do
      @settings.setdefaults :mysection, :one => ["whah", "yay"], :two => ["$one yay", "bah"]
      @settings[:two].should == "whah yay"
      @settings.handlearg("--one", "else")
      @settings[:two].should == "else yay"
    end

    it "should not clear other values when setting getopt-specific values" do
      @settings[:myval] = "yay"
      @settings.handlearg("--no-bool", "")
      @settings[:myval].should == "yay"
    end

    it "should clear the list of used sections" do
      @settings.expects(:clearused)
      @settings[:myval] = "yay"
    end

    it "should call passed blocks when values are set" do
      values = []
      @settings.setdefaults(:section, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| values << v }})
      values.should == []

      @settings[:hooker] = "something"
      values.should == %w{something}
    end

    it "should call passed blocks when values are set via the command line" do
      values = []
      @settings.setdefaults(:section, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| values << v }})
      values.should == []

      @settings.handlearg("--hooker", "yay")

      values.should == %w{yay}
    end

    it "should provide an option to call passed blocks during definition" do
      values = []
      @settings.setdefaults(:section, :hooker => {:default => "yay", :desc => "boo", :call_on_define => true, :hook => lambda { |v| values << v }})
      values.should == %w{yay}
    end

    it "should pass the fully interpolated value to the hook when called on definition" do
      values = []
      @settings.setdefaults(:section, :one => ["test", "a"])
      @settings.setdefaults(:section, :hooker => {:default => "$one/yay", :desc => "boo", :call_on_define => true, :hook => lambda { |v| values << v }})
      values.should == %w{test/yay}
    end

    it "should munge values using the setting-specific methods" do
      @settings[:bool] = "false"
      @settings[:bool].should == false
    end

    it "should prefer cli values to values set in Ruby code" do
      @settings.handlearg("--myval", "cliarg")
      @settings[:myval] = "memarg"
      @settings[:myval].should == "cliarg"
    end

    it "should clear the list of environments" do
      Puppet::Node::Environment.expects(:clear).at_least(1)
      @settings[:myval] = "memarg"
    end

    it "should raise an error if we try to set 'name'" do
      lambda{ @settings[:name] = "foo" }.should raise_error(ArgumentError)
    end

    it "should raise an error if we try to set 'run_mode'" do
      lambda{ @settings[:run_mode] = "foo" }.should raise_error(ArgumentError)
    end

    it "should warn and use [master] if we ask for [puppetmasterd]" do
      Puppet.expects(:warning)
      @settings.set_value(:myval, "foo", :puppetmasterd)

      @settings.stubs(:run_mode).returns(:master)
      @settings.value(:myval).should == "foo"
    end

    it "should warn and use [agent] if we ask for [puppetd]" do
      Puppet.expects(:warning)
      @settings.set_value(:myval, "foo", :puppetd)

      @settings.stubs(:run_mode).returns(:agent)
      @settings.value(:myval).should == "foo"
    end
  end

  describe "when returning values" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.setdefaults :section, :config => ["/my/file", "eh"], :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"], :four => ["$two $three FOUR", "d"]
      FileTest.stubs(:exist?).returns true
    end

    it "should provide a mechanism for returning set values" do
      @settings[:one] = "other"
      @settings[:one].should == "other"
    end

    it "should interpolate default values for other parameters into returned parameter values" do
      @settings[:one].should == "ONE"
      @settings[:two].should == "ONE TWO"
      @settings[:three].should == "ONE ONE TWO THREE"
    end

    it "should interpolate default values that themselves need to be interpolated" do
      @settings[:four].should == "ONE TWO ONE ONE TWO THREE FOUR"
    end

    it "should provide a method for returning uninterpolated values" do
      @settings[:two] = "$one tw0"
      @settings.uninterpolated_value(:two).should  == "$one tw0"
      @settings.uninterpolated_value(:four).should == "$two $three FOUR"
    end

    it "should interpolate set values for other parameters into returned parameter values" do
      @settings[:one] = "on3"
      @settings[:two] = "$one tw0"
      @settings[:three] = "$one $two thr33"
      @settings[:four] = "$one $two $three f0ur"
      @settings[:one].should == "on3"
      @settings[:two].should == "on3 tw0"
      @settings[:three].should == "on3 on3 tw0 thr33"
      @settings[:four].should == "on3 on3 tw0 on3 on3 tw0 thr33 f0ur"
    end

    it "should not cache interpolated values such that stale information is returned" do
      @settings[:two].should == "ONE TWO"
      @settings[:one] = "one"
      @settings[:two].should == "one TWO"
    end

    it "should not cache values such that information from one environment is returned for another environment" do
      text = "[env1]\none = oneval\n[env2]\none = twoval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.parse

      @settings.value(:one, "env1").should == "oneval"
      @settings.value(:one, "env2").should == "twoval"
    end

    it "should have a run_mode that defaults to user" do
      @settings.run_mode.should == :user
    end
  end

  describe "when choosing which value to return" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.setdefaults :section,
        :config => ["/my/file", "a"],
        :one => ["ONE", "a"],
        :two => ["TWO", "b"]
      FileTest.stubs(:exist?).returns true
      Puppet.stubs(:run_mode).returns stub('run_mode', :name => :mymode)
    end

    it "should return default values if no values have been set" do
      @settings[:one].should == "ONE"
    end

    it "should return values set on the cli before values set in the configuration file" do
      text = "[main]\none = fileval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.handlearg("--one", "clival")
      @settings.parse

      @settings[:one].should == "clival"
    end

    it "should return values set on the cli before values set in Ruby" do
      @settings[:one] = "rubyval"
      @settings.handlearg("--one", "clival")
      @settings[:one].should == "clival"
    end

    it "should return values set in the mode-specific section before values set in the main section" do
      text = "[main]\none = mainval\n[mymode]\none = modeval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.parse

      @settings[:one].should == "modeval"
    end

    it "should not return values outside of its search path" do
      text = "[other]\none = oval\n"
      file = "/some/file"
      @settings.stubs(:read_file).returns(text)
      @settings.parse
      @settings[:one].should == "ONE"
    end

    it "should return values in a specified environment" do
      text = "[env]\none = envval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.parse
      @settings.value(:one, "env").should == "envval"
    end

    it 'should use the current environment for $environment' do
      @settings.setdefaults :main, :myval => ["$environment/foo", "mydocs"]

      @settings.value(:myval, "myenv").should == "myenv/foo"
    end

    it "should interpolate found values using the current environment" do
      text = "[main]\none = mainval\n[myname]\none = nameval\ntwo = $one/two\n"
      @settings.stubs(:read_file).returns(text)
      @settings.parse

      @settings.value(:two, "myname").should == "nameval/two"
    end

    it "should return values in a specified environment before values in the main or name sections" do
      text = "[env]\none = envval\n[main]\none = mainval\n[myname]\none = nameval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.parse
      @settings.value(:one, "env").should == "envval"
    end
  end

  describe "when parsing its configuration" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.stubs(:service_user_available?).returns true
      @file = "/some/file"
      @settings.setdefaults :section, :user => ["suser", "doc"], :group => ["sgroup", "doc"]
      @settings.setdefaults :section, :config => ["/some/file", "eh"], :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
      FileTest.stubs(:exist?).returns true
    end

    it "should not ignore the report setting" do
      @settings.setdefaults :section, :report => ["false", "a"]
      myfile = stub "myfile"
      @settings[:config] = myfile
      text = <<-CONF
        [puppetd]
          report=true
      CONF
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:report].should be_true
    end

    it "should use its current ':config' value for the file to parse" do
      myfile = make_absolute("/my/file") # do not stub expand_path here, as this leads to a stack overflow, when mocha tries to use it
      @settings[:config] = myfile

      File.expects(:read).with(myfile).returns "[main]"

      @settings.parse
    end

    it "should fail if no configuration setting is defined" do
      @settings = Puppet::Util::Settings.new
      lambda { @settings.parse }.should raise_error(RuntimeError)
    end

    it "should not try to parse non-existent files" do
      FileTest.expects(:exist?).with("/some/file").returns false

      File.expects(:read).with("/some/file").never

      @settings.parse
    end

    it "should set a timer that triggers reparsing, even if the file does not exist" do
      FileTest.expects(:exist?).returns false
      @settings.expects(:set_filetimeout_timer)

      @settings.parse
    end

    it "should return values set in the configuration file" do
      text = "[main]
      one = fileval
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:one].should == "fileval"
    end

    #484 - this should probably be in the regression area
    it "should not throw an exception on unknown parameters" do
      text = "[main]\nnosuchparam = mval\n"
      @settings.expects(:read_file).returns(text)
      lambda { @settings.parse }.should_not raise_error
    end

    it "should convert booleans in the configuration file into Ruby booleans" do
      text = "[main]
      one = true
      two = false
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:one].should == true
      @settings[:two].should == false
    end

    it "should convert integers in the configuration file into Ruby Integers" do
      text = "[main]
      one = 65
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:one].should == 65
    end

    it "should support specifying all metadata (owner, group, mode) in the configuration file" do
      @settings.setdefaults :section, :myfile => ["/myfile", "a"]

      otherfile = make_absolute("/other/file")
      text = "[main]
      myfile = #{otherfile} {owner = service, group = service, mode = 644}
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:myfile].should == otherfile
      @settings.metadata(:myfile).should == {:owner => "suser", :group => "sgroup", :mode => "644"}
    end

    it "should support specifying a single piece of metadata (owner, group, or mode) in the configuration file" do
      @settings.setdefaults :section, :myfile => ["/myfile", "a"]

      otherfile = make_absolute("/other/file")
      text = "[main]
      myfile = #{otherfile} {owner = service}
      "
      file = "/some/file"
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:myfile].should == otherfile
      @settings.metadata(:myfile).should == {:owner => "suser"}
    end

    it "should call hooks associated with values set in the configuration file" do
      values = []
      @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      text = "[main]
      mysetting = setval
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      values.should == ["setval"]
    end

    it "should not call the same hook for values set multiple times in the configuration file" do
      values = []
      @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      text = "[user]
      mysetting = setval
      [main]
      mysetting = other
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      values.should == ["setval"]
    end

    it "should pass the environment-specific value to the hook when one is available" do
      values = []
      @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}
      @settings.setdefaults :section, :environment => ["yay", "a"]
      @settings.setdefaults :section, :environments => ["yay,foo", "a"]

      text = "[main]
      mysetting = setval
      [yay]
      mysetting = other
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      values.should == ["other"]
    end

    it "should pass the interpolated value to the hook when one is available" do
      values = []
      @settings.setdefaults :section, :base => {:default => "yay", :desc => "a", :hook => proc { |v| values << v }}
      @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      text = "[main]
      mysetting = $base/setval
      "
      @settings.expects(:read_file).returns(text)
      @settings.parse
      values.should == ["yay/setval"]
    end

    it "should allow empty values" do
      @settings.setdefaults :section, :myarg => ["myfile", "a"]

      text = "[main]
      myarg =
      "
      @settings.stubs(:read_file).returns(text)
      @settings.parse
      @settings[:myarg].should == ""
    end

    describe "and when reading a non-positive filetimeout value from the config file" do
      before do
        @settings.setdefaults :foo, :filetimeout => [5, "eh"]

        somefile = "/some/file"
        text = "[main]
        filetimeout = -1
        "
        File.expects(:read).with(somefile).returns(text)
        File.expects(:expand_path).with(somefile).returns somefile
        @settings[:config] = somefile
      end

      it "should not set a timer" do
        EventLoop::Timer.expects(:new).never

        @settings.parse
      end
    end
  end

  describe "when reparsing its configuration" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.setdefaults :section, :config => ["/test/file", "a"], :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
      FileTest.stubs(:exist?).returns true
    end

    it "should use a LoadedFile instance to determine if the file has changed" do
      file = mock 'file'
      Puppet::Util::LoadedFile.expects(:new).with("/test/file").returns file

      file.expects(:changed?)

      @settings.stubs(:parse)
      @settings.reparse
    end

    it "should not create the LoadedFile instance and should not parse if the file does not exist" do
      FileTest.expects(:exist?).with("/test/file").returns false
      Puppet::Util::LoadedFile.expects(:new).never

      @settings.expects(:parse).never

      @settings.reparse
    end

    it "should not reparse if the file has not changed" do
      file = mock 'file'
      Puppet::Util::LoadedFile.expects(:new).with("/test/file").returns file

      file.expects(:changed?).returns false

      @settings.expects(:parse).never

      @settings.reparse
    end

    it "should reparse if the file has changed" do
      file = stub 'file', :file => "/test/file"
      Puppet::Util::LoadedFile.expects(:new).with("/test/file").returns file

      file.expects(:changed?).returns true

      @settings.expects(:parse)

      @settings.reparse
    end

    it "should replace in-memory values with on-file values" do
      # Init the value
      text = "[main]\none = disk-init\n"
      file = mock 'file'
      file.stubs(:changed?).returns(true)
      file.stubs(:file).returns("/test/file")
      @settings[:one] = "init"
      @settings.file = file

      # Now replace the value
      text = "[main]\none = disk-replace\n"

      # This is kinda ridiculous - the reason it parses twice is that
      # it goes to parse again when we ask for the value, because the
      # mock always says it should get reparsed.
      @settings.stubs(:read_file).returns(text)
      @settings.reparse
      @settings[:one].should == "disk-replace"
    end

    it "should retain parameters set by cli when configuration files are reparsed" do
      @settings.handlearg("--one", "clival")

      text = "[main]\none = on-disk\n"
      @settings.stubs(:read_file).returns(text)
      @settings.parse

      @settings[:one].should == "clival"
    end

    it "should remove in-memory values that are no longer set in the file" do
      # Init the value
      text = "[main]\none = disk-init\n"
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:one].should == "disk-init"

      # Now replace the value
      text = "[main]\ntwo = disk-replace\n"
      @settings.expects(:read_file).returns(text)
      @settings.parse
      #@settings.reparse

      # The originally-overridden value should be replaced with the default
      @settings[:one].should == "ONE"

      # and we should now have the new value in memory
      @settings[:two].should == "disk-replace"
    end

    it "should retain in-memory values if the file has a syntax error" do
      # Init the value
      text = "[main]\none = initial-value\n"
      @settings.expects(:read_file).returns(text)
      @settings.parse
      @settings[:one].should == "initial-value"

      # Now replace the value with something bogus
      text = "[main]\nkenny = killed-by-what-follows\n1 is 2, blah blah florp\n"
      @settings.expects(:read_file).returns(text)
      @settings.parse

      # The originally-overridden value should not be replaced with the default
      @settings[:one].should == "initial-value"

      # and we should not have the new value in memory
      @settings[:kenny].should be_nil
    end
  end

  it "should provide a method for creating a catalog of resources from its configuration" do
    Puppet::Util::Settings.new.should respond_to(:to_catalog)
  end

  describe "when creating a catalog" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.stubs(:service_user_available?).returns true
      @prefix = Puppet.features.posix? ? "" : "C:"
    end

    it "should add all file resources to the catalog if no sections have been specified" do
      @settings.setdefaults :main, :maindir => [@prefix+"/maindir", "a"], :seconddir => [@prefix+"/seconddir", "a"]
      @settings.setdefaults :other, :otherdir => [@prefix+"/otherdir", "a"]

      catalog = @settings.to_catalog

      [@prefix+"/maindir", @prefix+"/seconddir", @prefix+"/otherdir"].each do |path|
        catalog.resource(:file, path).should be_instance_of(Puppet::Resource)
      end
    end

    it "should add only files in the specified sections if section names are provided" do
      @settings.setdefaults :main, :maindir => [@prefix+"/maindir", "a"]
      @settings.setdefaults :other, :otherdir => [@prefix+"/otherdir", "a"]
      catalog = @settings.to_catalog(:main)
      catalog.resource(:file, @prefix+"/otherdir").should be_nil
      catalog.resource(:file, @prefix+"/maindir").should be_instance_of(Puppet::Resource)
    end

    it "should not try to add the same file twice" do
      @settings.setdefaults :main, :maindir => [@prefix+"/maindir", "a"]
      @settings.setdefaults :other, :otherdir => [@prefix+"/maindir", "a"]
      lambda { @settings.to_catalog }.should_not raise_error
    end

    it "should ignore files whose :to_resource method returns nil" do
      @settings.setdefaults :main, :maindir => [@prefix+"/maindir", "a"]
      @settings.setting(:maindir).expects(:to_resource).returns nil

      Puppet::Resource::Catalog.any_instance.expects(:add_resource).never
      @settings.to_catalog
    end

    describe "on Microsoft Windows" do
      before :each do
        Puppet.features.stubs(:root?).returns true
        Puppet.features.stubs(:microsoft_windows?).returns true

        @settings.setdefaults :foo, :mkusers => [true, "e"], :user => ["suser", "doc"], :group => ["sgroup", "doc"]
        @settings.setdefaults :other, :otherdir => {:default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        @catalog = @settings.to_catalog
      end

      it "it should not add users and groups to the catalog" do
        @catalog.resource(:user, "suser").should be_nil
        @catalog.resource(:group, "sgroup").should be_nil
      end
    end

    describe "when adding users and groups to the catalog" do
      before do
        Puppet.features.stubs(:root?).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false

        @settings.setdefaults :foo, :mkusers => [true, "e"], :user => ["suser", "doc"], :group => ["sgroup", "doc"]
        @settings.setdefaults :other, :otherdir => {:default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        @catalog = @settings.to_catalog
      end

      it "should add each specified user and group to the catalog if :mkusers is a valid setting, is enabled, and we're running as root" do
        @catalog.resource(:user, "suser").should be_instance_of(Puppet::Resource)
        @catalog.resource(:group, "sgroup").should be_instance_of(Puppet::Resource)
      end

      it "should only add users and groups to the catalog from specified sections" do
        @settings.setdefaults :yay, :yaydir => {:default => "/yaydir", :desc => "a", :owner => "service", :group => "service"}
        catalog = @settings.to_catalog(:other)
        catalog.resource(:user, "jane").should be_nil
        catalog.resource(:group, "billy").should be_nil
      end

      it "should not add users or groups to the catalog if :mkusers not running as root" do
        Puppet.features.stubs(:root?).returns false

        catalog = @settings.to_catalog
        catalog.resource(:user, "suser").should be_nil
        catalog.resource(:group, "sgroup").should be_nil
      end

      it "should not add users or groups to the catalog if :mkusers is not a valid setting" do
        Puppet.features.stubs(:root?).returns true
        settings = Puppet::Util::Settings.new
        settings.setdefaults :other, :otherdir => {:default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        catalog = settings.to_catalog
        catalog.resource(:user, "suser").should be_nil
        catalog.resource(:group, "sgroup").should be_nil
      end

      it "should not add users or groups to the catalog if :mkusers is a valid setting but is disabled" do
        @settings[:mkusers] = false

        catalog = @settings.to_catalog
        catalog.resource(:user, "suser").should be_nil
        catalog.resource(:group, "sgroup").should be_nil
      end

      it "should not try to add users or groups to the catalog twice" do
        @settings.setdefaults :yay, :yaydir => {:default => "/yaydir", :desc => "a", :owner => "service", :group => "service"}

        # This would fail if users/groups were added twice
        lambda { @settings.to_catalog }.should_not raise_error
      end

      it "should set :ensure to :present on each created user and group" do
        @catalog.resource(:user, "suser")[:ensure].should == :present
        @catalog.resource(:group, "sgroup")[:ensure].should == :present
      end

      it "should set each created user's :gid to the service group" do
        @settings.to_catalog.resource(:user, "suser")[:gid].should == "sgroup"
      end

      it "should not attempt to manage the root user" do
        Puppet.features.stubs(:root?).returns true
        @settings.setdefaults :foo, :foodir => {:default => "/foodir", :desc => "a", :owner => "root", :group => "service"}

        @settings.to_catalog.resource(:user, "root").should be_nil
      end
    end
  end

  it "should be able to be converted to a manifest" do
    Puppet::Util::Settings.new.should respond_to(:to_manifest)
  end

  describe "when being converted to a manifest" do
    it "should produce a string with the code for each resource joined by two carriage returns" do
      @settings = Puppet::Util::Settings.new
      @settings.setdefaults :main, :maindir => ["/maindir", "a"], :seconddir => ["/seconddir", "a"]

      main = stub 'main_resource', :ref => "File[/maindir]"
      main.expects(:to_manifest).returns "maindir"
      second = stub 'second_resource', :ref => "File[/seconddir]"
      second.expects(:to_manifest).returns "seconddir"
      @settings.setting(:maindir).expects(:to_resource).returns main
      @settings.setting(:seconddir).expects(:to_resource).returns second

      @settings.to_manifest.split("\n\n").sort.should == %w{maindir seconddir}
    end
  end

  describe "when using sections of the configuration to manage the local host" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.stubs(:service_user_available?).returns true
      @settings.setdefaults :main, :noop => [false, ""]
      @settings.setdefaults :main, :maindir => ["/maindir", "a"], :seconddir => ["/seconddir", "a"]
      @settings.setdefaults :main, :user => ["suser", "doc"], :group => ["sgroup", "doc"]
      @settings.setdefaults :other, :otherdir => {:default => "/otherdir", :desc => "a", :owner => "service", :group => "service", :mode => 0755}
      @settings.setdefaults :third, :thirddir => ["/thirddir", "b"]
      @settings.setdefaults :files, :myfile => {:default => "/myfile", :desc => "a", :mode => 0755}
    end

    it "should provide a method that writes files with the correct modes" do
      @settings.should respond_to(:write)
    end

    it "should provide a method that creates directories with the correct modes" do
      Puppet::Util::SUIDManager.expects(:asuser).with("suser", "sgroup").yields
      Dir.expects(:mkdir).with("/otherdir", 0755)
      @settings.mkdir(:otherdir)
    end

    it "should create a catalog with the specified sections" do
      @settings.expects(:to_catalog).with(:main, :other).returns Puppet::Resource::Catalog.new("foo")
      @settings.use(:main, :other)
    end

    it "should canonicalize the sections" do
      @settings.expects(:to_catalog).with(:main, :other).returns Puppet::Resource::Catalog.new("foo")
      @settings.use("main", "other")
    end

    it "should ignore sections that have already been used" do
      @settings.expects(:to_catalog).with(:main).returns Puppet::Resource::Catalog.new("foo")
      @settings.use(:main)
      @settings.expects(:to_catalog).with(:other).returns Puppet::Resource::Catalog.new("foo")
      @settings.use(:main, :other)
    end

    it "should ignore tags and schedules when creating files and directories"

    it "should be able to provide all of its parameters in a format compatible with GetOpt::Long" do
      pending "Not converted from test/unit yet"
    end

    it "should convert the created catalog to a RAL catalog" do
      @catalog = Puppet::Resource::Catalog.new("foo")
      @settings.expects(:to_catalog).with(:main).returns @catalog

      @catalog.expects(:to_ral).returns @catalog
      @settings.use(:main)
    end

    it "should specify that it is not managing a host catalog" do
      catalog = Puppet::Resource::Catalog.new("foo")
      catalog.expects(:apply)
      @settings.expects(:to_catalog).returns catalog

      catalog.stubs(:to_ral).returns catalog

      catalog.expects(:host_config=).with false

      @settings.use(:main)
    end

    it "should support a method for re-using all currently used sections" do
      @settings.expects(:to_catalog).with(:main, :third).times(2).returns Puppet::Resource::Catalog.new("foo")

      @settings.use(:main, :third)
      @settings.reuse
    end

    it "should fail with an appropriate message if any resources fail" do
      @catalog = Puppet::Resource::Catalog.new("foo")
      @catalog.stubs(:to_ral).returns @catalog
      @settings.expects(:to_catalog).returns @catalog

      @trans = mock("transaction")
      @catalog.expects(:apply).yields(@trans)

      @trans.expects(:any_failed?).returns(true)

      report = mock 'report'
      @trans.expects(:report).returns report

      log = mock 'log', :to_s => "My failure", :level => :err
      report.expects(:logs).returns [log]

      @settings.expects(:raise).with { |msg| msg.include?("My failure") }
      @settings.use(:whatever)
    end
  end

  describe "when dealing with printing configs" do
    before do
      @settings = Puppet::Util::Settings.new
      #these are the magic default values
      @settings.stubs(:value).with(:configprint).returns("")
      @settings.stubs(:value).with(:genconfig).returns(false)
      @settings.stubs(:value).with(:genmanifest).returns(false)
      @settings.stubs(:value).with(:environment).returns(nil)
    end

    describe "when checking print_config?" do
      it "should return false when the :configprint, :genconfig and :genmanifest are not set" do
        @settings.print_configs?.should be_false
      end

      it "should return true when :configprint has a value" do
        @settings.stubs(:value).with(:configprint).returns("something")
        @settings.print_configs?.should be_true
      end

      it "should return true when :genconfig has a value" do
        @settings.stubs(:value).with(:genconfig).returns(true)
        @settings.print_configs?.should be_true
      end

      it "should return true when :genmanifest has a value" do
        @settings.stubs(:value).with(:genmanifest).returns(true)
        @settings.print_configs?.should be_true
      end
    end

    describe "when printing configs" do
      describe "when :configprint has a value" do
        it "should call print_config_options" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.expects(:print_config_options)
          @settings.print_configs
        end

        it "should get the value of the option using the environment" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(true)
          @settings.expects(:value).with(:environment).returns("env")
          @settings.expects(:value).with("something", "env").returns("foo")
          @settings.stubs(:puts).with("foo")
          @settings.print_configs
        end

        it "should print the value of the option" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(true)
          @settings.stubs(:value).with("something", nil).returns("foo")
          @settings.expects(:puts).with("foo")
          @settings.print_configs
        end

        it "should print the value pairs if there are multiple options" do
          @settings.stubs(:value).with(:configprint).returns("bar,baz")
          @settings.stubs(:include?).with("bar").returns(true)
          @settings.stubs(:include?).with("baz").returns(true)
          @settings.stubs(:value).with("bar", nil).returns("foo")
          @settings.stubs(:value).with("baz", nil).returns("fud")
          @settings.expects(:puts).with("bar = foo")
          @settings.expects(:puts).with("baz = fud")
          @settings.print_configs
        end

        it "should print a whole bunch of stuff if :configprint = all"

        it "should return true after printing" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(true)
          @settings.stubs(:value).with("something", nil).returns("foo")
          @settings.stubs(:puts).with("foo")
          @settings.print_configs.should be_true
        end

        it "should return false if a config param is not found" do
          @settings.stubs :puts
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(false)
          @settings.print_configs.should be_false
        end
      end

      describe "when genconfig is true" do
        before do
          @settings.stubs :puts
        end

        it "should call to_config" do
          @settings.stubs(:value).with(:genconfig).returns(true)
          @settings.expects(:to_config)
          @settings.print_configs
        end

        it "should return true from print_configs" do
          @settings.stubs(:value).with(:genconfig).returns(true)
          @settings.stubs(:to_config)
          @settings.print_configs.should be_true
        end
      end

      describe "when genmanifest is true" do
        before do
          @settings.stubs :puts
        end

        it "should call to_config" do
          @settings.stubs(:value).with(:genmanifest).returns(true)
          @settings.expects(:to_manifest)
          @settings.print_configs
        end

        it "should return true from print_configs" do
          @settings.stubs(:value).with(:genmanifest).returns(true)
          @settings.stubs(:to_manifest)
          @settings.print_configs.should be_true
        end
      end
    end
  end

  describe "when setting a timer to trigger configuration file reparsing" do
    before do
      @settings = Puppet::Util::Settings.new
      @settings.setdefaults :foo, :filetimeout => [5, "eh"]
    end

    it "should do nothing if no filetimeout setting is available" do
      @settings.expects(:value).with(:filetimeout).returns nil
      EventLoop::Timer.expects(:new).never
      @settings.set_filetimeout_timer
    end

    it "should always convert the timer interval to an integer" do
      @settings.expects(:value).with(:filetimeout).returns "10"
      EventLoop::Timer.expects(:new).with(:interval => 10, :start? => true, :tolerance => 1)
      @settings.set_filetimeout_timer
    end

    it "should do nothing if the filetimeout setting is not greater than 0" do
      @settings.expects(:value).with(:filetimeout).returns -2
      EventLoop::Timer.expects(:new).never
      @settings.set_filetimeout_timer
    end

    it "should create a timer with its interval set to the filetimeout, start? set to true, and a tolerance of 1" do
      @settings.expects(:value).with(:filetimeout).returns 5
      EventLoop::Timer.expects(:new).with(:interval => 5, :start? => true, :tolerance => 1)

      @settings.set_filetimeout_timer
    end

    it "should reparse when the timer goes off" do
      EventLoop::Timer.expects(:new).with(:interval => 5, :start? => true, :tolerance => 1).yields

      @settings.expects(:reparse)

      @settings.set_filetimeout_timer
    end
  end

  describe "when determining if the service user is available" do
    it "should return false if there is no user setting" do
      Puppet::Util::Settings.new.should_not be_service_user_available
    end

    it "should return false if the user provider says the user is missing" do
      settings = Puppet::Util::Settings.new
      settings.setdefaults :main, :user => ["foo", "doc"]

      user = mock 'user'
      user.expects(:exists?).returns false

      Puppet::Type.type(:user).expects(:new).with { |args| args[:name] == "foo" }.returns user

      settings.should_not be_service_user_available
    end

    it "should return true if the user provider says the user is present" do
      settings = Puppet::Util::Settings.new
      settings.setdefaults :main, :user => ["foo", "doc"]

      user = mock 'user'
      user.expects(:exists?).returns true

      Puppet::Type.type(:user).expects(:new).with { |args| args[:name] == "foo" }.returns user

      settings.should be_service_user_available
    end

    it "should cache the result"
  end

  describe "#writesub" do
    it "should only pass valid arguments to File.open" do
      settings = Puppet::Util::Settings.new
      settings.stubs(:get_config_file_default).with(:privatekeydir).returns(OpenStruct.new(:mode => "750"))

      File.expects(:open).with("/path/to/keydir", "w", 750).returns true
      settings.writesub(:privatekeydir, "/path/to/keydir")
    end
  end
end
