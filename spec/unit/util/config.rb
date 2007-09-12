#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Util::Config, " when specifying defaults" do
    before do
        @config = Puppet::Util::Config.new
    end

    it "should start with no defined parameters" do
        @config.params.length.should == 0
    end

    it "should allow specification of default values associated with a section as an array" do
        @config.setdefaults(:section, :myvalue => ["defaultval", "my description"])
    end

    it "should not allow duplicate parameter specifications" do
        @config.setdefaults(:section, :myvalue => ["a", "b"])
        lambda { @config.setdefaults(:section, :myvalue => ["c", "d"]) }.should raise_error(ArgumentError)
    end

    it "should allow specification of default values associated with a section as a hash" do
        @config.setdefaults(:section, :myvalue => {:default => "defaultval", :desc => "my description"})
    end

    it "should consider defined parameters to be valid" do
        @config.setdefaults(:section, :myvalue => ["defaultval", "my description"])
        @config.valid?(:myvalue).should be_true
    end

    it "should require a description when defaults are specified with an array" do
        lambda { @config.setdefaults(:section, :myvalue => ["a value"]) }.should raise_error(ArgumentError)
    end

    it "should require a description when defaults are specified with a hash" do
        lambda { @config.setdefaults(:section, :myvalue => {:default => "a value"}) }.should raise_error(ArgumentError)
    end

    it "should support specifying owner, group, and mode when specifying files" do
        @config.setdefaults(:section, :myvalue => {:default => "/some/file", :owner => "blah", :mode => "boo", :group => "yay", :desc => "whatever"})
    end

    it "should support specifying a short name" do
        @config.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
    end

    it "should fail when short names conflict" do
        @config.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
        lambda { @config.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"}) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Util::Config, " when setting values" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :main, :myval => ["val", "desc"]
        @config.setdefaults :main, :bool => [true, "desc"]
    end

    it "should provide a method for setting values from other objects" do
        @config[:myval] = "something else"
        @config[:myval].should == "something else"
    end

    it "should support a getopt-specific mechanism for setting values" do
        @config.handlearg("--myval", "newval")
        @config[:myval].should == "newval"
    end

    it "should support a getopt-specific mechanism for turning booleans off" do
        @config.handlearg("--no-bool")
        @config[:bool].should == false
    end

    it "should support a getopt-specific mechanism for turning booleans on" do
        # Turn it off first
        @config[:bool] = false
        @config.handlearg("--bool")
        @config[:bool].should == true
    end

    it "should clear the cache when setting getopt-specific values" do
        @config.setdefaults :mysection, :one => ["whah", "yay"], :two => ["$one yay", "bah"]
        @config[:two].should == "whah yay"
        @config.handlearg("--one", "else")
        @config[:two].should == "else yay"
    end

    it "should not clear other values when setting getopt-specific values" do
        @config[:myval] = "yay"
        @config.handlearg("--no-bool")
        @config[:myval].should == "yay"
    end

    it "should call passed blocks when values are set" do
        values = []
        @config.setdefaults(:section, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| values << v }})
        values.should == []

        @config[:hooker] = "something"
        values.should == %w{something}
    end

    it "should munge values using the element-specific methods" do
        @config[:bool] = "false"
        @config[:bool].should == false
    end

    it "should prefer cli values to values set in Ruby code" do
        @config.handlearg("--myval", "cliarg")
        @config[:myval] = "memarg"
        @config[:myval].should == "cliarg"
    end
end

describe Puppet::Util::Config, " when returning values" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"], :four => ["$two $three FOUR", "d"]
    end

    it "should provide a mechanism for returning set values" do
        @config[:one] = "other"
        @config[:one].should == "other"
    end

    it "should interpolate default values for other parameters into returned parameter values" do
        @config[:one].should == "ONE"
        @config[:two].should == "ONE TWO"
        @config[:three].should == "ONE ONE TWO THREE"
    end

    it "should interpolate default values that themselves need to be interpolated" do
        @config[:four].should == "ONE TWO ONE ONE TWO THREE FOUR"
    end

    it "should interpolate set values for other parameters into returned parameter values" do
        @config[:one] = "on3"
        @config[:two] = "$one tw0"
        @config[:three] = "$one $two thr33"
        @config[:four] = "$one $two $three f0ur"
        @config[:one].should == "on3"
        @config[:two].should == "on3 tw0"
        @config[:three].should == "on3 on3 tw0 thr33"
        @config[:four].should == "on3 on3 tw0 on3 on3 tw0 thr33 f0ur"
    end

    it "should not cache interpolated values such that stale information is returned" do
        @config[:two].should == "ONE TWO"
        @config[:one] = "one"
        @config[:two].should == "one TWO"
    end

    it "should not cache values such that information from one environment is returned for another environment" do
        text = "[env1]\none = oneval\n[env2]\none = twoval\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @config.stubs(:read_file).with(file).returns(text)
        @config.parse(file)

        @config.value(:one, "env1").should == "oneval"
        @config.value(:one, "env2").should == "twoval"
    end

    it "should have a name determined by the 'name' parameter" do
        @config.setdefaults(:whatever, :name => ["something", "yayness"])
        @config.name.should == :something
        @config[:name] = :other
        @config.name.should == :other
    end
end

describe Puppet::Util::Config, " when choosing which value to return" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :section,
            :one => ["ONE", "a"],
            :name => ["myname", "w"]
    end

    it "should return default values if no values have been set" do
        @config[:one].should == "ONE"
    end

    it "should return values set on the cli before values set in the configuration file" do
        text = "[main]\none = fileval\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @config.stubs(:parse_file).returns(text)
        @config.handlearg("--one", "clival")
        @config.parse(file)

        @config[:one].should == "clival"
    end

    it "should return values set on the cli before values set in Ruby" do
        @config[:one] = "rubyval"
        @config.handlearg("--one", "clival")
        @config[:one].should == "clival"
    end

    it "should return values set in the executable-specific section before values set in the main section" do
        text = "[main]\none = mainval\n[myname]\none = nameval\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @config.stubs(:read_file).with(file).returns(text)
        @config.parse(file)

        @config[:one].should == "nameval"
    end

    it "should not return values outside of its search path" do
        text = "[other]\none = oval\n"
        file = "/some/file"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @config.stubs(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:one].should == "ONE"
    end

    it "should return values in a specified environment" do
        text = "[env]\none = envval\n"
        file = "/some/file"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @config.stubs(:read_file).with(file).returns(text)
        @config.parse(file)
        @config.value(:one, "env").should == "envval"
    end

    it "should return values in a specified environment before values in the main or name sections" do
        text = "[env]\none = envval\n[main]\none = mainval\n[myname]\none = nameval\n"
        file = "/some/file"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @config.stubs(:read_file).with(file).returns(text)
        @config.parse(file)
        @config.value(:one, "env").should == "envval"
    end
end

describe Puppet::Util::Config, " when parsing its configuration" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
    end

    it "should return values set in the configuration file" do
        text = "[main]
        one = fileval
        "
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:one].should == "fileval"
    end

    #484 - this should probably be in the regression area
    it "should not throw an exception on unknown parameters" do
        text = "[main]\nnosuchparam = mval\n"
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        lambda { @config.parse(file) }.should_not raise_error
    end

    it "should support an old parse method when per-executable configuration files still exist" do
        # I'm not going to bother testing this method.
        @config.should respond_to(:old_parse)
    end

    it "should convert booleans in the configuration file into Ruby booleans" do
        text = "[main]
        one = true
        two = false
        "
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:one].should == true
        @config[:two].should == false
    end

    it "should convert integers in the configuration file into Ruby Integers" do
        text = "[main]
        one = 65
        "
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:one].should == 65
    end

    it "should support specifying file all metadata (owner, group, mode) in the configuration file" do
        @config.setdefaults :section, :myfile => ["/my/file", "a"]

        text = "[main]
        myfile = /other/file {owner = luke, group = luke, mode = 644}
        "
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:myfile].should == "/other/file"
        @config.metadata(:myfile).should == {:owner => "luke", :group => "luke", :mode => "644"}
    end

    it "should support specifying file a single piece of metadata (owner, group, or mode) in the configuration file" do
        @config.setdefaults :section, :myfile => ["/my/file", "a"]

        text = "[main]
        myfile = /other/file {owner = luke}
        "
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:myfile].should == "/other/file"
        @config.metadata(:myfile).should == {:owner => "luke"}
    end
end

describe Puppet::Util::Config, " when reparsing its configuration" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
    end

    it "should replace in-memory values with on-file values" do
        # Init the value
        text = "[main]\none = disk-init\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/test/file")
        @config[:one] = "init"
        @config.file = file

        # Now replace the value
        text = "[main]\none = disk-replace\n"
        
        # This is kinda ridiculous - the reason it parses twice is that
        # it goes to parse again when we ask for the value, because the
        # mock always says it should get reparsed.
        @config.expects(:read_file).with(file).returns(text).times(2)
        @config.reparse
        @config[:one].should == "disk-replace"
    end

    it "should retain parameters set by cli when configuration files are reparsed" do
        @config.handlearg("--one", "clival")

        text = "[main]\none = on-disk\n"
        file = mock 'file'
        file.stubs(:file).returns("/test/file")
        @config.stubs(:read_file).with(file).returns(text)
        @config.parse(file)

        @config[:one].should == "clival"
    end

    it "should remove in-memory values that are no longer set in the file" do
        # Init the value
        text = "[main]\none = disk-init\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/test/file")
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:one].should == "disk-init"

        # Now replace the value
        text = "[main]\ntwo = disk-replace\n"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        #@config.reparse

        # The originally-overridden value should be replaced with the default
        @config[:one].should == "ONE"

        # and we should now have the new value in memory
        @config[:two].should == "disk-replace"
    end
end

describe Puppet::Util::Config, " when being used to manage the host machine" do
    it "should provide a method that writes files with the correct modes" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method that creates directories with the correct modes" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method to declare what directories should exist" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method to trigger enforcing of file modes on existing files and directories" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method to convert the file mode enforcement into a Puppet manifest" do
        pending "Not converted from test/unit yet"
    end

    it "should provide an option to create needed users and groups" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method to print out the current configuration" do
        pending "Not converted from test/unit yet"
    end

    it "should be able to provide all of its parameters in a format compatible with GetOpt::Long" do
        pending "Not converted from test/unit yet"
    end

    it "should not attempt to manage files within /dev" do
        pending "Not converted from test/unit yet"
    end
end
