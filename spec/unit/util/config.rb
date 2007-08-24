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

    it "should fail when a parameter has already been defined" do
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

    it "should support a mechanism for setting values in a specific search section" do
        pending "This code requires the search path functionality"
        #@config.set(:myval, "new value", :cli)
        #@config[:myval].should == "new value"
    end
end

describe Puppet::Util::Config, " when returning values" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
    end

    it "should provide a mechanism for returning set values" do
        @config[:one] = "other"
        @config[:one].should == "other"
    end

    it "should return default values if no values have been set" do
        @config[:one].should == "ONE"
    end

    it "should support a search path for finding values" do
        pending "I have no idea how this will work yet"
    end

    it "should return set values in the order defined in the search path" do
        pending "Still no clear idea how this will work"
    end

    it "should interpolate other parameters into returned parameter values" do
        @config[:one].should == "ONE"
        @config[:two].should == "ONE TWO"
        @config[:three].should == "ONE ONE TWO THREE"
    end

    it "should not cache interpolated values such that stale information is returned" do
        @config[:two].should == "ONE TWO"
        @config[:one] = "one"
        @config[:two].should == "one TWO"
    end
end

describe Puppet::Util::Config, " when parsing its configuration" do
    before do
        @config = Puppet::Util::Config.new
        @config.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
    end

    it "should not return values outside of its search path" do
        text = "[main]
        one = mval
        [other]
        two = oval
        "
        file = "/some/file"
        @config.expects(:read_file).with(file).returns(text)
        @config.parse(file)
        @config[:one].should == "mval"
        @config[:two].should == "mval TWO"
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
        @config.handlearg("--one", "myval")
        @config[:two] = "otherval"
    end
end

describe Puppet::Util::Config, " when being used to manage the host machine" do
    it "should provide a method that writes files with the correct modes"

    it "should provide a method that creates directories with the correct modes"

    it "should provide a method to declare what directories should exist"

    it "should provide a method to trigger enforcing of file modes on existing files and directories"

    it "should provide a method to convert the file mode enforcement into a Puppet manifest"

    it "should provide an option to create needed users and groups"

    it "should provide a method to print out the current configuration"

    it "should be able to provide all of its parameters in a format compatible with GetOpt::Long"

    it "should not attempt to manage files within /dev"
end
