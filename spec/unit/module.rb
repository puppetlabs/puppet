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

describe Puppet::Module, " when searching for templates" do
    it "should return fully-qualified templates directly" do
        Puppet::Module.expects(:modulepath).never
        Puppet::Module.find_template("/my/template").should == "/my/template"
    end

    it "should return the template from the first found module" do
        mod = mock 'module'
        Puppet::Node::Environment.new.expects(:module).with("mymod").returns mod

        mod.expects(:template).returns("/one/mymod/templates/mytemplate")
        Puppet::Module.find_template("mymod/mytemplate").should == "/one/mymod/templates/mytemplate"
    end
    
    it "should return the file in the templatedir if it exists" do
        Puppet.settings.expects(:value).with(:templatedir, nil).returns("/my/templates")
        Puppet[:modulepath] = "/one:/two"
        File.stubs(:directory?).returns(true)
        FileTest.stubs(:exist?).returns(true)
        Puppet::Module.find_template("mymod/mytemplate").should == "/my/templates/mymod/mytemplate"
    end

    it "should raise an error if no valid templatedir exists" do
        Puppet::Module.stubs(:templatepath).with(nil).returns(nil)
        lambda { Puppet::Module.find_template("mytemplate") }.should raise_error
    end

    it "should not raise an error if no valid templatedir exists and the template exists in a module" do
        mod = mock 'module'
        Puppet::Node::Environment.new.expects(:module).with("mymod").returns mod

        mod.expects(:template).returns("/one/mymod/templates/mytemplate")
        Puppet::Module.stubs(:templatepath).with(nil).returns(nil)

        Puppet::Module.find_template("mymod/mytemplate").should == "/one/mymod/templates/mytemplate"
    end

    it "should use the main templatedir if no module is found" do
        Puppet::Module.stubs(:templatepath).with(nil).returns(["/my/templates"])
        Puppet::Module.expects(:find).with("mymod", nil).returns(nil)
        Puppet::Module.find_template("mymod/mytemplate").should == "/my/templates/mymod/mytemplate"
    end

    it "should return unqualified templates directly in the template dir" do
        Puppet::Module.stubs(:templatepath).with(nil).returns(["/my/templates"])
        Puppet::Module.expects(:find).never
        Puppet::Module.find_template("mytemplate").should == "/my/templates/mytemplate"
    end

    it "should accept relative templatedirs" do
        Puppet[:templatedir] = "my/templates"
        File.expects(:directory?).with(File.join(Dir.getwd,"my/templates")).returns(true)
        Puppet::Module.find_template("mytemplate").should == File.join(Dir.getwd,"my/templates/mytemplate")
    end

    it "should use the environment templatedir if no module is found and an environment is specified" do
        Puppet::Module.stubs(:templatepath).with("myenv").returns(["/myenv/templates"])
        Puppet::Module.expects(:find).with("mymod", "myenv").returns(nil)
        Puppet::Module.find_template("mymod/mytemplate", "myenv").should == "/myenv/templates/mymod/mytemplate"
    end

    it "should use first dir from environment templatedir if no module is found and an environment is specified" do
        Puppet::Module.stubs(:templatepath).with("myenv").returns(["/myenv/templates", "/two/templates"])
        Puppet::Module.expects(:find).with("mymod", "myenv").returns(nil)
        Puppet::Module.find_template("mymod/mytemplate", "myenv").should == "/myenv/templates/mymod/mytemplate"
    end

    it "should use a valid dir when templatedir is a path for unqualified templates and the first dir contains template" do
        Puppet::Module.stubs(:templatepath).returns(["/one/templates", "/two/templates"])
        FileTest.expects(:exist?).with("/one/templates/mytemplate").returns(true)
        Puppet::Module.expects(:find).never
        Puppet::Module.find_template("mytemplate").should == "/one/templates/mytemplate"
    end

    it "should use a valid dir when templatedir is a path for unqualified templates and only second dir contains template" do
        Puppet::Module.stubs(:templatepath).returns(["/one/templates", "/two/templates"])
        FileTest.expects(:exist?).with("/one/templates/mytemplate").returns(false)
        FileTest.expects(:exist?).with("/two/templates/mytemplate").returns(true)
        Puppet::Module.expects(:find).never
        Puppet::Module.find_template("mytemplate").should == "/two/templates/mytemplate"
    end

    it "should use the node environment if specified" do
        mod = mock 'module'
        Puppet::Node::Environment.new("myenv").expects(:module).with("mymod").returns mod

        mod.expects(:template).returns("/my/modules/mymod/templates/envtemplate")

        Puppet::Module.find_template("mymod/envtemplate", "myenv").should == "/my/modules/mymod/templates/envtemplate"
    end

    after { Puppet.settings.clear }
end

describe Puppet::Module, " when searching for manifests when no module is found" do
    before do
        File.stubs(:find).returns(nil)
    end

    it "should not look for modules when paths are fully qualified" do
        Puppet.expects(:value).with(:modulepath).never
        file = "/fully/qualified/file.pp"
        Dir.stubs(:glob).with(file).returns([file])
        Puppet::Module.find_manifests(file)
    end

    it "should directly return fully qualified files" do
        file = "/fully/qualified/file.pp"
        Dir.stubs(:glob).with(file).returns([file])
        Puppet::Module.find_manifests(file).should == [file]
    end

    it "should match against provided fully qualified patterns" do
        pattern = "/fully/qualified/pattern/*"
        Dir.expects(:glob).with(pattern).returns(%w{my file list})
        Puppet::Module.find_manifests(pattern).should == %w{my file list}
    end

    it "should look for files relative to the current directory" do
        cwd = Dir.getwd
        Dir.expects(:glob).with("#{cwd}/foobar/init.pp").returns(["#{cwd}/foobar/init.pp"])
        Puppet::Module.find_manifests("foobar/init.pp").should == ["#{cwd}/foobar/init.pp"]
    end

    it "should only return files, not directories" do
        pattern = "/fully/qualified/pattern/*"
        file = "/my/file"
        dir = "/my/directory"
        Dir.expects(:glob).with(pattern).returns([file, dir])
        FileTest.expects(:directory?).with(file).returns(false)
        FileTest.expects(:directory?).with(dir).returns(true)
        Puppet::Module.find_manifests(pattern).should == [file]
    end
end

describe Puppet::Module, " when searching for manifests in a found module" do
    before do
        @module = Puppet::Module.new("mymod", "/one")
    end

    it "should return the manifests from the first found module" do
        mod = mock 'module'
        Puppet::Node::Environment.new.expects(:module).with("mymod").returns mod
        mod.expects(:match_manifests).with("init.pp").returns(%w{/one/mymod/manifests/init.pp})
        Puppet::Module.find_manifests("mymod/init.pp").should == ["/one/mymod/manifests/init.pp"]
    end

    it "should use the node environment if specified" do
        mod = mock 'module'
        Puppet::Node::Environment.new("myenv").expects(:module).with("mymod").returns mod
        mod.expects(:match_manifests).with("init.pp").returns(%w{/one/mymod/manifests/init.pp})
        Puppet::Module.find_manifests("mymod/init.pp", :environment => "myenv").should == ["/one/mymod/manifests/init.pp"]
    end

    it "should return all manifests matching the glob pattern" do
        File.stubs(:directory?).returns(true)
        Dir.expects(:glob).with("/one/manifests/yay/*.pp").returns(%w{/one /two})

        @module.match_manifests("yay/*.pp").should == %w{/one /two}
    end

    it "should not return directories" do
        Dir.expects(:glob).with("/one/manifests/yay/*.pp").returns(%w{/one /two})

        FileTest.expects(:directory?).with("/one").returns false
        FileTest.expects(:directory?).with("/two").returns true

        @module.match_manifests("yay/*.pp").should == %w{/one}
    end

    it "should default to the 'init.pp' file in the manifests directory" do
        Dir.expects(:glob).with("/one/manifests/init.pp").returns(%w{/init.pp})

        @module.match_manifests(nil).should == %w{/init.pp}
    end

    after { Puppet.settings.clear }
end

describe Puppet::Module, " when returning files" do
    it "should return the path to the module's 'files' directory" do
        mod = Puppet::Module.send(:new, "mymod", "/my/mod")
        mod.files.should == "/my/mod/files"
    end
end
