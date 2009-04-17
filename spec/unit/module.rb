#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Module do
    [:plugins, :templates, :files, :manifests].each do |filetype|
        it "should be able to indicate whether it has #{filetype}" do
            Puppet::Module.new("foo", "/foo/bar").should respond_to(filetype.to_s + "?")
        end

        it "should correctly detect when it has #{filetype}" do
            FileTest.expects(:exist?).with("/foo/bar/#{filetype}").returns true
            Puppet::Module.new("foo", "/foo/bar").send(filetype.to_s + "?").should be_true
        end

        it "should correctly detect when it does not have #{filetype}" do
            FileTest.expects(:exist?).with("/foo/bar/#{filetype}").returns false
            Puppet::Module.new("foo", "/foo/bar").send(filetype.to_s + "?").should be_false
        end

        it "should have a method for returning the full path to the #{filetype}" do
            Puppet::Module.new("foo", "/foo/bar").send(filetype.to_s).should == File.join("/foo/bar", filetype.to_s)
        end

        it "should be able to return individual #{filetype}" do
            path = File.join("/foo/bar", filetype.to_s, "my/file")
            FileTest.expects(:exist?).with(path).returns true
            Puppet::Module.new("foo", "/foo/bar").send(filetype.to_s.sub(/s$/, ''), "my/file").should == path
        end

        it "should return nil if asked to return individual #{filetype} that don't exist" do
            FileTest.expects(:exist?).with(File.join("/foo/bar", filetype.to_s, "my/file")).returns false
            Puppet::Module.new("foo", "/foo/bar").send(filetype.to_s.sub(/s$/, ''), "my/file").should be_nil
        end

        it "should return the base directory if asked for a nil path" do
            path = File.join("/foo/bar", filetype.to_s)
            FileTest.expects(:exist?).with(path).returns true
            Puppet::Module.new("foo", "/foo/bar").send(filetype.to_s.sub(/s$/, ''), nil).should == path
        end
    end
end

describe Puppet::Module, "when yielding each module in a list of directories" do
    before do
        FileTest.stubs(:directory?).returns true
    end

    it "should search for modules in each directory in the list" do
        Dir.expects(:entries).with("/one").returns []
        Dir.expects(:entries).with("/two").returns []

        Puppet::Module.each_module("/one", "/two")
    end

    it "should accept the list of directories as an array" do
        Dir.expects(:entries).with("/one").returns []
        Dir.expects(:entries).with("/two").returns []

        Puppet::Module.each_module(%w{/one /two})
    end

    it "should accept the list of directories joined by #{File::PATH_SEPARATOR}" do
        Dir.expects(:entries).with("/one").returns []
        Dir.expects(:entries).with("/two").returns []

        list = %w{/one /two}.join(File::PATH_SEPARATOR)

        Puppet::Module.each_module(list)
    end

    it "should not create modules for '.' or '..' in the provided directory list" do
        Dir.expects(:entries).with("/one").returns(%w{. ..})

        result = []
        Puppet::Module.each_module("/one") do |mod|
            result << mod
        end

        result.should be_empty
    end

    it "should not create modules for non-directories in the provided directory list" do
        Dir.expects(:entries).with("/one").returns(%w{notdir})

        FileTest.expects(:directory?).with("/one/notdir").returns false

        result = []
        Puppet::Module.each_module("/one") do |mod|
            result << mod
        end

        result.should be_empty
    end

    it "should yield each found module" do
        Dir.expects(:entries).with("/one").returns(%w{f1 f2})

        one = mock 'one'
        two = mock 'two'

        Puppet::Module.expects(:new).with("f1", "/one/f1").returns one
        Puppet::Module.expects(:new).with("f2", "/one/f2").returns two

        result = []
        Puppet::Module.each_module("/one") do |mod|
            result << mod
        end

        result.should == [one, two]
    end

    it "should not yield a module with the same name as a previously yielded module" do
        Dir.expects(:entries).with("/one").returns(%w{f1})
        Dir.expects(:entries).with("/two").returns(%w{f1})

        one = mock 'one'

        Puppet::Module.expects(:new).with("f1", "/one/f1").returns one
        Puppet::Module.expects(:new).with("f1", "/two/f1").never

        result = []
        Puppet::Module.each_module("/one", "/two") do |mod|
            result << mod
        end

        result.should == [one]
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

describe Puppet::Module, " when searching for modules" do
    it "should use the current environment to find the specified module if no environment is provided" do
        env = mock 'env'
        env.expects(:module).with("foo").returns "yay"
        Puppet::Node::Environment.expects(:new).with(nil).returns env

        Puppet::Module.find("foo").should == "yay"
    end

    it "should use the specified environment to find the specified module if an environment is provided" do
        env = mock 'env'
        env.expects(:module).with("foo").returns "yay"
        Puppet::Node::Environment.expects(:new).with("myenv").returns env

        Puppet::Module.find("foo", "myenv").should == "yay"
    end
end

describe Puppet::Module, " when returning files" do
    it "should return the path to the module's 'files' directory" do
        mod = Puppet::Module.send(:new, "mymod", "/my/mod")
        mod.files.should == "/my/mod/files"
    end
end
