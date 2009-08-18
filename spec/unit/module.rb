#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Module do
    before do
        # This is necessary because of the extra checks we have for the deprecated
        # 'plugins' directory
        FileTest.stubs(:exist?).returns false
    end

    it "should have a class method that returns a named module from a given environment" do
        env = mock 'module'
        env.expects(:module).with("mymod").returns "yep"
        Puppet::Node::Environment.expects(:new).with("myenv").returns env

        Puppet::Module.find("mymod", "myenv").should == "yep"
    end

    it "should return nil if asked for a named module that doesn't exist" do
        env = mock 'module'
        env.expects(:module).with("mymod").returns nil
        Puppet::Node::Environment.expects(:new).with("myenv").returns env

        Puppet::Module.find("mymod", "myenv").should be_nil
    end

    it "should return nil if asked for a module whose name is 'nil'" do
        Puppet::Module.find(nil, "myenv").should be_nil
    end

    it "should provide support for logging" do
        Puppet::Module.ancestors.should be_include(Puppet::Util::Logging)
    end

    it "should be able to be converted to a string" do
        Puppet::Module.new("foo").to_s.should == "Module foo"
    end

    it "should add the path to its string form if the module is found" do
        mod = Puppet::Module.new("foo")
        mod.stubs(:path).returns "/a"
        mod.to_s.should == "Module foo(/a)"
    end

    it "should fail if its name is not alphanumeric" do
        lambda { Puppet::Module.new(".something") }.should raise_error(Puppet::Module::InvalidName)
    end

    it "should require a name at initialization" do
        lambda { Puppet::Module.new }.should raise_error(ArgumentError)
    end

    it "should convert an environment name into an Environment instance" do
        Puppet::Module.new("foo", "prod").environment.should be_instance_of(Puppet::Node::Environment)
    end

    it "should accept an environment at initialization" do
        Puppet::Module.new("foo", :prod).environment.name.should == :prod
    end

    it "should use the default environment if none is provided" do
        env = Puppet::Node::Environment.new
        Puppet::Module.new("foo").environment.should equal(env)
    end

    it "should use any provided Environment instance" do
        env = Puppet::Node::Environment.new
        Puppet::Module.new("foo", env).environment.should equal(env)
    end

    it "should return the path to the first found instance in its environment's module paths as its path" do
        mod = Puppet::Module.new("foo")
        env = mock 'environment'
        mod.stubs(:environment).returns env

        env.expects(:modulepath).returns %w{/a /b /c}

        FileTest.expects(:exist?).with("/a/foo").returns false
        FileTest.expects(:exist?).with("/b/foo").returns true
        FileTest.expects(:exist?).with("/c/foo").never

        mod.path.should == "/b/foo"
    end

    it "should be considered existent if it exists in at least one module path" do
        mod = Puppet::Module.new("foo")
        mod.expects(:path).returns "/a/foo"
        mod.should be_exist
    end

    it "should be considered nonexistent if it does not exist in any of the module paths" do
        mod = Puppet::Module.new("foo")
        mod.expects(:path).returns nil
        mod.should_not be_exist
    end

    [:plugins, :templates, :files, :manifests].each do |filetype|
        dirname = filetype == :plugins ? "lib" : filetype.to_s
        it "should be able to return individual #{filetype}" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns "/a/foo"
            path = File.join("/a/foo", dirname, "my/file")
            FileTest.expects(:exist?).with(path).returns true
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should == path
        end

        it "should consider #{filetype} to be present if their base directory exists" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns "/a/foo"
            path = File.join("/a/foo", dirname)
            FileTest.expects(:exist?).with(path).returns true
            mod.send(filetype.to_s + "?").should be_true
        end

        it "should consider #{filetype} to be absent if their base directory does not exist" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns "/a/foo"
            path = File.join("/a/foo", dirname)
            FileTest.expects(:exist?).with(path).returns false
            mod.send(filetype.to_s + "?").should be_false
        end

        it "should consider #{filetype} to be absent if the module base directory does not exist" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns nil
            mod.send(filetype.to_s + "?").should be_false
        end

        it "should return nil if asked to return individual #{filetype} that don't exist" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns "/a/foo"
            path = File.join("/a/foo", dirname, "my/file")
            FileTest.expects(:exist?).with(path).returns false
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should be_nil
        end

        it "should return nil when asked for individual #{filetype} if the module does not exist" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns nil
            mod.send(filetype.to_s.sub(/s$/, ''), "my/file").should be_nil
        end

        it "should return the base directory if asked for a nil path" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns "/a/foo"
            base = File.join("/a/foo", dirname)
            FileTest.expects(:exist?).with(base).returns true
            mod.send(filetype.to_s.sub(/s$/, ''), nil).should == base
        end
    end

    %w{plugins files}.each do |filetype|
        short = filetype.sub(/s$/, '')
        dirname = filetype == "plugins" ? "lib" : filetype.to_s
        it "should be able to return the #{short} directory" do
            Puppet::Module.new("foo").should respond_to(short + "_directory")
        end

        it "should return the path to the #{short} directory" do
            mod = Puppet::Module.new("foo")
            mod.stubs(:path).returns "/a/foo"

            mod.send(short + "_directory").should == "/a/foo/#{dirname}"
        end
    end

    it "should throw a warning if plugins are in a 'plugins' directory rather than a 'lib' directory" do
        mod = Puppet::Module.new("foo")
        mod.stubs(:path).returns "/a/foo"
        FileTest.expects(:exist?).with("/a/foo/plugins").returns true

        mod.expects(:warning)

        mod.plugin_directory.should == "/a/foo/plugins"
    end

    it "should default to 'lib' for the plugins directory" do
        mod = Puppet::Module.new("foo")
        mod.stubs(:path).returns "/a/foo"
        mod.plugin_directory.should == "/a/foo/lib"
    end
end

describe Puppet::Module, " when building its search path" do
    it "should use the current environment's search path if no environment is specified" do
        env = mock 'env'
        env.expects(:modulepath).returns "eh"
        Puppet::Node::Environment.expects(:new).with(nil).returns env

        Puppet::Module.modulepath.should == "eh"
    end

    it "should use the specified environment's search path if an environment is specified" do
        env = mock 'env'
        env.expects(:modulepath).returns "eh"
        Puppet::Node::Environment.expects(:new).with("foo").returns env

        Puppet::Module.modulepath("foo").should == "eh"
    end
end

describe Puppet::Module, "when finding matching manifests" do
    before do
        @mod = Puppet::Module.new("mymod")
        @mod.stubs(:path).returns "/a"
    end

    it "should return all manifests matching the glob pattern" do
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns(%w{foo bar})

        @mod.match_manifests("yay/*.pp").should == %w{foo bar}
    end

    it "should not return directories" do
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns(%w{foo bar})

        FileTest.expects(:directory?).with("foo").returns false
        FileTest.expects(:directory?).with("bar").returns true
        @mod.match_manifests("yay/*.pp").should == %w{foo}
    end

    it "should default to the 'init.pp' file if no glob pattern is specified" do
        FileTest.stubs(:exist?).returns true

        @mod.match_manifests(nil).should == %w{/a/manifests/init.pp}
    end

    it "should return all manifests matching the glob pattern in all existing paths" do
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns(%w{a b})

        @mod.match_manifests("yay/*.pp").should == %w{a b}
    end

    it "should match the glob pattern plus '.pp' if no results are found" do
        Dir.expects(:glob).with("/a/manifests/yay/foo").returns([])
        Dir.expects(:glob).with("/a/manifests/yay/foo.pp").returns(%w{yay})

        @mod.match_manifests("yay/foo").should == %w{yay}
    end

    it "should return an empty array if no manifests matched" do
        Dir.expects(:glob).with("/a/manifests/yay/*.pp").returns([])

        @mod.match_manifests("yay/*.pp").should == []
    end
end
