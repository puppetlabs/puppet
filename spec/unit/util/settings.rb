#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Util::Settings, " when specifying defaults" do
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

    it "should support specifying owner, group, and mode when specifying files" do
        @settings.setdefaults(:section, :myvalue => {:default => "/some/file", :owner => "blah", :mode => "boo", :group => "yay", :desc => "whatever"})
    end

    it "should support specifying a short name" do
        @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
    end

    it "should fail when short names conflict" do
        @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
        lambda { @settings.setdefaults(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"}) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Util::Settings, " when setting values" do
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
        @settings.handlearg("--no-bool")
        @settings[:bool].should == false
    end

    it "should support a getopt-specific mechanism for turning booleans on" do
        # Turn it off first
        @settings[:bool] = false
        @settings.handlearg("--bool")
        @settings[:bool].should == true
    end

    it "should clear the cache when setting getopt-specific values" do
        @settings.setdefaults :mysection, :one => ["whah", "yay"], :two => ["$one yay", "bah"]
        @settings[:two].should == "whah yay"
        @settings.handlearg("--one", "else")
        @settings[:two].should == "else yay"
    end

    it "should not clear other values when setting getopt-specific values" do
        @settings[:myval] = "yay"
        @settings.handlearg("--no-bool")
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

    it "should munge values using the element-specific methods" do
        @settings[:bool] = "false"
        @settings[:bool].should == false
    end

    it "should prefer cli values to values set in Ruby code" do
        @settings.handlearg("--myval", "cliarg")
        @settings[:myval] = "memarg"
        @settings[:myval].should == "cliarg"
    end
end

describe Puppet::Util::Settings, " when returning values" do
    before do
        @settings = Puppet::Util::Settings.new
        @settings.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"], :four => ["$two $three FOUR", "d"]
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
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @settings.stubs(:read_file).with(file).returns(text)
        @settings.parse(file)

        @settings.value(:one, "env1").should == "oneval"
        @settings.value(:one, "env2").should == "twoval"
    end

    it "should have a name determined by the 'name' parameter" do
        @settings.setdefaults(:whatever, :name => ["something", "yayness"])
        @settings.name.should == :something
        @settings[:name] = :other
        @settings.name.should == :other
    end
end

describe Puppet::Util::Settings, " when choosing which value to return" do
    before do
        @settings = Puppet::Util::Settings.new
        @settings.setdefaults :section,
            :one => ["ONE", "a"],
            :name => ["myname", "w"]
    end

    it "should return default values if no values have been set" do
        @settings[:one].should == "ONE"
    end

    it "should return values set on the cli before values set in the configuration file" do
        text = "[main]\none = fileval\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @settings.stubs(:parse_file).returns(text)
        @settings.handlearg("--one", "clival")
        @settings.parse(file)

        @settings[:one].should == "clival"
    end

    it "should return values set on the cli before values set in Ruby" do
        @settings[:one] = "rubyval"
        @settings.handlearg("--one", "clival")
        @settings[:one].should == "clival"
    end

    it "should return values set in the executable-specific section before values set in the main section" do
        text = "[main]\none = mainval\n[myname]\none = nameval\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @settings.stubs(:read_file).with(file).returns(text)
        @settings.parse(file)

        @settings[:one].should == "nameval"
    end

    it "should not return values outside of its search path" do
        text = "[other]\none = oval\n"
        file = "/some/file"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @settings.stubs(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:one].should == "ONE"
    end

    it "should return values in a specified environment" do
        text = "[env]\none = envval\n"
        file = "/some/file"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @settings.stubs(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings.value(:one, "env").should == "envval"
    end

    it "should return values in a specified environment before values in the main or name sections" do
        text = "[env]\none = envval\n[main]\none = mainval\n[myname]\none = nameval\n"
        file = "/some/file"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        @settings.stubs(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings.value(:one, "env").should == "envval"
    end
end

describe Puppet::Util::Settings, " when parsing its configuration" do
    before do
        @settings = Puppet::Util::Settings.new
        @settings.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
    end

    it "should return values set in the configuration file" do
        text = "[main]
        one = fileval
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:one].should == "fileval"
    end

    #484 - this should probably be in the regression area
    it "should not throw an exception on unknown parameters" do
        text = "[main]\nnosuchparam = mval\n"
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        lambda { @settings.parse(file) }.should_not raise_error
    end

    it "should convert booleans in the configuration file into Ruby booleans" do
        text = "[main]
        one = true
        two = false
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:one].should == true
        @settings[:two].should == false
    end

    it "should convert integers in the configuration file into Ruby Integers" do
        text = "[main]
        one = 65
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:one].should == 65
    end

    it "should support specifying all metadata (owner, group, mode) in the configuration file" do
        @settings.setdefaults :section, :myfile => ["/myfile", "a"]

        text = "[main]
        myfile = /other/file {owner = luke, group = luke, mode = 644}
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:myfile].should == "/other/file"
        @settings.metadata(:myfile).should == {:owner => "luke", :group => "luke", :mode => "644"}
    end

    it "should support specifying a single piece of metadata (owner, group, or mode) in the configuration file" do
        @settings.setdefaults :section, :myfile => ["/myfile", "a"]

        text = "[main]
        myfile = /other/file {owner = luke}
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:myfile].should == "/other/file"
        @settings.metadata(:myfile).should == {:owner => "luke"}
    end

    it "should call hooks associated with values set in the configuration file" do
        values = []
        @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

        text = "[main]
        mysetting = setval
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        values.should == ["setval"]
    end

    it "should not call the same hook for values set multiple times in the configuration file" do
        values = []
        @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

        text = "[main]
        mysetting = setval
        [puppet]
        mysetting = other
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
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
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        values.should == ["other"]
    end

    it "should pass the interpolated value to the hook when one is available" do
        values = []
        @settings.setdefaults :section, :base => {:default => "yay", :desc => "a", :hook => proc { |v| values << v }}
        @settings.setdefaults :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

        text = "[main]
        mysetting = $base/setval
        "
        file = "/some/file"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        values.should == ["yay/setval"]
    end

    it "should allow empty values" do
        @settings.setdefaults :section, :myarg => ["myfile", "a"]

        text = "[main]
        myarg =
        "
        @settings.stubs(:read_file).returns(text)
        @settings.parse("/some/file")
        @settings[:myarg].should == ""
    end
end

describe Puppet::Util::Settings, " when reparsing its configuration" do
    before do
        @settings = Puppet::Util::Settings.new
        @settings.setdefaults :section, :one => ["ONE", "a"], :two => ["$one TWO", "b"], :three => ["$one $two THREE", "c"]
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
        @settings.expects(:read_file).with(file).returns(text).times(2)
        @settings.reparse
        @settings[:one].should == "disk-replace"
    end

    it "should retain parameters set by cli when configuration files are reparsed" do
        @settings.handlearg("--one", "clival")

        text = "[main]\none = on-disk\n"
        file = mock 'file'
        file.stubs(:file).returns("/test/file")
        @settings.stubs(:read_file).with(file).returns(text)
        @settings.parse(file)

        @settings[:one].should == "clival"
    end

    it "should remove in-memory values that are no longer set in the file" do
        # Init the value
        text = "[main]\none = disk-init\n"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/test/file")
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        @settings[:one].should == "disk-init"

        # Now replace the value
        text = "[main]\ntwo = disk-replace\n"
        @settings.expects(:read_file).with(file).returns(text)
        @settings.parse(file)
        #@settings.reparse

        # The originally-overridden value should be replaced with the default
        @settings[:one].should == "ONE"

        # and we should now have the new value in memory
        @settings[:two].should == "disk-replace"
    end
end

describe Puppet::Util::Settings, " when being used to manage the host machine" do
    before do
        @settings = Puppet::Util::Settings.new
        @settings.setdefaults :main, :maindir => ["/maindir", "a"], :seconddir => ["/seconddir", "a"]
        @settings.setdefaults :other, :otherdir => {:default => "/otherdir", :desc => "a", :owner => "luke", :group => "johnny", :mode => 0755}
        @settings.setdefaults :third, :thirddir => ["/thirddir", "b"]
        @settings.setdefaults :files, :myfile => {:default => "/myfile", :desc => "a", :mode => 0755}
    end

    def stub_transaction
        @bucket = mock 'bucket'
        @config = mock 'config'
        @trans = mock 'transaction'

        @settings.expects(:to_transportable).with(:whatever).returns(@bucket)
        @bucket.expects(:to_catalog).returns(@config)
        @config.expects(:apply).yields(@trans)
        @config.stubs(:host_config=)
    end

    it "should provide a method that writes files with the correct modes" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method that creates directories with the correct modes" do
        Puppet::Util::SUIDManager.expects(:asuser).with("luke", "johnny").yields
        Dir.expects(:mkdir).with("/otherdir", 0755)
        @settings.mkdir(:otherdir)
    end

    it "should be able to create needed directories in a single section" do
        Dir.expects(:mkdir).with("/maindir")
        Dir.expects(:mkdir).with("/seconddir")
        @settings.use(:main)
    end

    it "should be able to create needed directories in multiple sections" do
        Dir.expects(:mkdir).with("/maindir")
        Dir.expects(:mkdir).with("/seconddir")
        Dir.expects(:mkdir).with("/thirddir")
        @settings.use(:main, :third)
    end

    it "should provide a method to trigger enforcing of file modes on existing files and directories" do
        pending "Not converted from test/unit yet"
    end

    it "should provide a method to convert the file mode enforcement into a Puppet manifest" do
        pending "Not converted from test/unit yet"
    end

    it "should create files when configured to do so with the :create parameter"

    it "should provide a method to convert the file mode enforcement into transportable resources" do
        # Make it think we're root so it tries to manage user and group.
        Puppet.features.stubs(:root?).returns(true)
        File.stubs(:exist?).with("/myfile").returns(true)
        trans = nil
        trans = @settings.to_transportable
        resources = []
        trans.delve { |obj| resources << obj if obj.is_a? Puppet::TransObject }
        %w{/maindir /seconddir /otherdir /myfile}.each do |path|
            obj = resources.find { |r| r.type == "file" and r.name == path }
            if path.include?("dir")
                obj[:ensure].should == :directory
            else
                # Do not create the file, just manage mode
                obj[:ensure].should be_nil
            end
            obj.should be_instance_of(Puppet::TransObject)
            case path
            when "/otherdir":
                obj[:owner].should == "luke"
                obj[:group].should == "johnny"
                obj[:mode].should == 0755
            when "/myfile":
                obj[:mode].should == 0755
            end
        end
    end

    it "should not try to manage user or group when not running as root" do
        Puppet.features.stubs(:root?).returns(false)
        trans = nil
        trans = @settings.to_transportable(:other)
        trans.delve do |obj|
            next unless obj.is_a?(Puppet::TransObject)
            obj[:owner].should be_nil
            obj[:group].should be_nil
        end
    end

    it "should add needed users and groups to the manifest when asked" do
        # This is how we enable user/group management
        @settings.setdefaults :main, :mkusers => [true, "w"]
        Puppet.features.stubs(:root?).returns(false)
        trans = nil
        trans = @settings.to_transportable(:other)
        resources = []
        trans.delve { |obj| resources << obj if obj.is_a? Puppet::TransObject and obj.type != "file" }

        user = resources.find { |r| r.type == "user" }
        user.should be_instance_of(Puppet::TransObject)
        user.name.should == "luke"
        user[:ensure].should == :present

        # This should maybe be a separate test, but...
        group = resources.find { |r| r.type == "group" }
        group.should be_instance_of(Puppet::TransObject)
        group.name.should == "johnny"
        group[:ensure].should == :present
    end

    it "should ignore tags and schedules when creating files and directories"

    it "should apply all resources in debug mode to reduce logging"

    it "should not try to manage absent files" do
        # Make it think we're root so it tries to manage user and group.
        Puppet.features.stubs(:root?).returns(true)
        trans = nil
        trans = @settings.to_transportable
        file = nil
        trans.delve { |obj| file = obj if obj.name == "/myfile" }
        file.should be_nil
    end

    it "should do nothing if a catalog cannot be created" do
        bucket = mock 'bucket'
        catalog = mock 'catalog'

        @settings.expects(:to_transportable).returns bucket
        bucket.expects(:to_catalog).raises RuntimeError
        catalog.expects(:apply).never

        @settings.use(:mysection)
    end

    it "should do nothing if all specified sections have already been used" do
        bucket = mock 'bucket'
        catalog = mock 'catalog'

        @settings.expects(:to_transportable).once.returns(bucket)
        bucket.expects(:to_catalog).returns catalog
        catalog.stub_everything

        @settings.use(:whatever)

        @settings.use(:whatever)
    end

    it "should ignore file settings whose values are not strings" do
        @settings[:maindir] = false

        lambda { trans = @settings.to_transportable }.should_not raise_error
    end

    it "should be able to turn the current configuration into a parseable manifest"

    it "should convert octal numbers correctly when producing a manifest"

    it "should be able to provide all of its parameters in a format compatible with GetOpt::Long" do
        pending "Not converted from test/unit yet"
    end

    it "should not attempt to manage files within /dev" do
        pending "Not converted from test/unit yet"
    end

    it "should not modify the stored state database when managing resources" do
        Puppet::Util::Storage.expects(:store).never
        Puppet::Util::Storage.expects(:load).never
        Dir.expects(:mkdir).with("/maindir")
        Dir.expects(:mkdir).with("/seconddir")
        @settings.use(:main)
    end

    it "should convert all relative paths to fully-qualified paths (#795)" do
        @settings[:myfile] = "unqualified"
        dir = Dir.getwd
        @settings[:myfile].should == File.join(dir, "unqualified")
    end

    it "should support a method for re-using all currently used sections" do
        Dir.expects(:mkdir).with("/thirddir").times(2)
        @settings.use(:third)
        @settings.reuse
    end

    it "should fail if any resources fail" do
        stub_transaction
        @trans.expects(:any_failed?).returns(true)

        proc { @settings.use(:whatever) }.should raise_error(RuntimeError)
    end
end
