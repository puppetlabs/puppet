#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Module, " when building its search path" do
    include PuppetTest

    it "should fully qualify unqualified paths in the search path" do
        Puppet[:modulepath] = "something:/my/something"
        File.stubs(:directory?).returns(true)
        Puppet::Module.modulepath.should == [File.join(Dir.getwd, 'something'), "/my/something"]
    end

    it "should ignore paths that do not exist" do
        Puppet[:modulepath] = "/yes:/no"
        File.expects(:directory?).with("/yes").returns(true)
        File.expects(:directory?).with("/no").returns(false)
        Puppet::Module.modulepath.should == %w{/yes}
    end

    it "should prepend PUPPETLIB in search path when set" do
        Puppet[:modulepath] = "/my/mod:/other/mod"
        ENV["PUPPETLIB"] = "/env/mod:/myenv/mod"
        File.stubs(:directory?).returns(true)
        Puppet::Module.modulepath.should == %w{/env/mod /myenv/mod /my/mod /other/mod}
    end

    it "should use the environment-specific search path when a node environment is provided" do
        Puppet.settings.expects(:value).with(:modulepath, "myenv").returns("/mone:/mtwo")
        File.stubs(:directory?).returns(true)
        Puppet::Module.modulepath("myenv").should == %w{/mone /mtwo}
    end

    after do
        ENV["PUPPETLIB"] = nil
    end
end

describe Puppet::Module, " when searching for modules" do
    it "should find modules in the search path" do
        path = %w{/dir/path}
        Puppet::Module.stubs(:modulepath).returns(path)
        File.stubs(:directory?).returns(true)
        mod = Puppet::Module.find("mymod")
        mod.should be_an_instance_of(Puppet::Module)
        mod.path.should == "/dir/path/mymod"
    end

    it "should not search for fully qualified modules" do
        path = %w{/dir/path}
        Puppet::Module.expects(:modulepath).never
        File.expects(:directory?).never
        Puppet::Module.find("/mymod").should be_nil
    end

    it "should search for modules in the order specified in the search path" do
        Puppet[:modulepath] = "/one:/two:/three"
        Puppet::Module.stubs(:modulepath).returns %w{/one /two /three}
        File.expects(:directory?).with("/one/mod").returns(false)
        File.expects(:directory?).with("/two/mod").returns(true)
        File.expects(:directory?).with("/three/mod").never
        mod = Puppet::Module.find("mod")
        mod.path.should == "/two/mod"
    end

    it "should use a node environment if specified" do
        Puppet::Module.expects(:modulepath).with("myenv").returns([])
        Puppet::Module.find("mymod", "myenv")
    end
end

describe Puppet::Module, " when searching for templates" do
    it "should return fully-qualified templates directly" do
        Puppet::Module.expects(:modulepath).never
        Puppet::Module.find_template("/my/template").should == "/my/template"
    end

    it "should return the template from the first found module" do
        Puppet[:modulepath] = "/one:/two"
        File.stubs(:directory?).returns(true)
        Puppet::Module.find_template("mymod/mytemplate").should == "/one/mymod/templates/mytemplate"
    end

    it "should use the main templatedir if no module is found" do
        Puppet.settings.expects(:value).with(:templatedir, nil).returns("/my/templates")
        Puppet::Module.expects(:find).with("mymod", nil).returns(nil)
        Puppet::Module.find_template("mymod/mytemplate").should == "/my/templates/mymod/mytemplate"
    end

    it "should return unqualified templates directly in the template dir" do
        Puppet.settings.expects(:value).with(:templatedir, nil).returns("/my/templates")
        Puppet::Module.expects(:find).never
        Puppet::Module.find_template("mytemplate").should == "/my/templates/mytemplate"
    end

    it "should use the environment templatedir if no module is found and an environment is specified" do
        Puppet.settings.expects(:value).with(:templatedir, "myenv").returns("/myenv/templates")
        Puppet::Module.expects(:find).with("mymod", "myenv").returns(nil)
        Puppet::Module.find_template("mymod/mytemplate", "myenv").should == "/myenv/templates/mymod/mytemplate"
    end

    it "should use the node environment if specified" do
        Puppet.settings.expects(:value).with(:modulepath, "myenv").returns("/my/templates")
        File.stubs(:directory?).returns(true)
        Puppet::Module.find_template("mymod/envtemplate", "myenv").should == "/my/templates/mymod/templates/envtemplate"
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
        Dir.expects(:glob).with("#{cwd}/mymod/init.pp").returns(["#{cwd}/mymod/init.pp"])
        Puppet::Module.find_manifests("mymod/init.pp").should == ["#{cwd}/mymod/init.pp"]
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
    it "should return the manifests from the first found module" do
        Puppet[:modulepath] = "/one:/two"
        File.stubs(:directory?).returns(true)
        Dir.expects(:glob).with("/one/mymod/manifests/init.pp").returns(%w{/one/mymod/manifests/init.pp})
        Puppet::Module.find_manifests("mymod/init.pp").should == ["/one/mymod/manifests/init.pp"]
    end

    it "should use the node environment if specified" do
        Puppet.settings.expects(:value).with(:modulepath, "myenv").returns("/env/modules")
        File.stubs(:directory?).returns(true)
        Dir.expects(:glob).with("/env/modules/mymod/manifests/envmanifest.pp").returns(%w{/env/modules/mymod/manifests/envmanifest.pp})
        Puppet::Module.find_manifests("mymod/envmanifest.pp", :environment => "myenv").should == ["/env/modules/mymod/manifests/envmanifest.pp"]
    end

    it "should return all manifests matching the glob pattern" do
        Puppet.settings.expects(:value).with(:modulepath, nil).returns("/my/modules")
        File.stubs(:directory?).returns(true)
        Dir.expects(:glob).with("/my/modules/mymod/manifests/yay/*.pp").returns(%w{/one /two})
        Puppet::Module.find_manifests("mymod/yay/*.pp").should == %w{/one /two}
    end

    it "should not return directories" do
        Puppet.settings.expects(:value).with(:modulepath, nil).returns("/my/modules")
        File.stubs(:directory?).returns(true)
        Dir.expects(:glob).with("/my/modules/mymod/manifests/yay/*.pp").returns(%w{/one /two})
        FileTest.expects(:directory?).with("/one").returns false
        FileTest.expects(:directory?).with("/two").returns true
        Puppet::Module.find_manifests("mymod/yay/*.pp").should == %w{/one}
    end

    it "should default to the 'init.pp' file in the manifests directory" do
        Puppet.settings.expects(:value).with(:modulepath, nil).returns("/my/modules")
        File.stubs(:directory?).returns(true)
        Dir.expects(:glob).with("/my/modules/mymod/manifests/init.pp").returns(%w{my manifest})
        Puppet::Module.find_manifests("mymod").should == %w{my manifest}
    end

    after { Puppet.settings.clear }
end

describe Puppet::Module, " when returning files" do
    it "should return the path to the module's 'files' directory" do
        mod = Puppet::Module.send(:new, "mymod", "/my/mod")
        mod.files.should == "/my/mod/files"
    end
end
