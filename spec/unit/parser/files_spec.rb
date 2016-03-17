#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parser/files'

describe Puppet::Parser::Files do
  include PuppetSpec::Files

  let(:environment) { Puppet::Node::Environment.create(:testing, []) }

  before do
    @basepath = make_absolute("/somepath")
  end

  describe "when searching for files" do
    it "should return fully-qualified files directly" do
      Puppet::Parser::Files.expects(:modulepath).never
      Puppet::Parser::Files.find_file(@basepath + "/my/file", environment).should == @basepath + "/my/file"
    end

    it "should return the first found file" do
      mod = mock 'module'
      mod.expects(:file).returns("/one/mymod/files/myfile")
      environment.expects(:module).with("mymod").returns mod

      Puppet::Parser::Files.find_file("mymod/myfile", environment).should == "/one/mymod/files/myfile"
    end

    it "should return nil if template is not found" do
      Puppet::Parser::Files.find_file("foomod/myfile", environment).should be_nil
    end
  end

  describe "when searching for templates" do
    it "should return fully-qualified templates directly" do
      Puppet::Parser::Files.expects(:modulepath).never
      Puppet::Parser::Files.find_template(@basepath + "/my/template", environment).should == @basepath + "/my/template"
    end

    it "should return the template from the first found module" do
      mod = mock 'module'
      mod.expects(:template).returns("/one/mymod/templates/mytemplate")
      environment.expects(:module).with("mymod").returns mod

      Puppet::Parser::Files.find_template("mymod/mytemplate", environment).should == "/one/mymod/templates/mytemplate"
    end

    it "should return the file in the templatedir if it exists" do
      Puppet[:templatedir] = "/my/templates"
      Puppet[:modulepath] = "/one:/two"
      File.stubs(:directory?).returns(true)
      Puppet::FileSystem.stubs(:exist?).returns(true)
      Puppet::Parser::Files.find_template("mymod/mytemplate", environment).should == File.join(Puppet[:templatedir], "mymod/mytemplate")
    end

    it "should not raise an error if no valid templatedir exists and the template exists in a module" do
      mod = mock 'module'
      mod.expects(:template).returns("/one/mymod/templates/mytemplate")
      environment.expects(:module).with("mymod").returns mod
      Puppet::Parser::Files.stubs(:templatepath).with(environment).returns(nil)

      Puppet::Parser::Files.find_template("mymod/mytemplate", environment).should == "/one/mymod/templates/mytemplate"
    end

    it "should return unqualified templates if they exist in the template dir" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Puppet::Parser::Files.stubs(:templatepath).with(environment).returns(["/my/templates"])

      Puppet::Parser::Files.find_template("mytemplate", environment).should == "/my/templates/mytemplate"
    end

    it "should only return templates if they actually exist" do
      Puppet::FileSystem.expects(:exist?).with("/my/templates/mytemplate").returns true
      Puppet::Parser::Files.stubs(:templatepath).with(environment).returns(["/my/templates"])
      Puppet::Parser::Files.find_template("mytemplate", environment).should == "/my/templates/mytemplate"
    end

    it "should return nil when asked for a template that doesn't exist" do
      Puppet::FileSystem.expects(:exist?).with("/my/templates/mytemplate").returns false
      Puppet::Parser::Files.stubs(:templatepath).with(environment).returns(["/my/templates"])
      Puppet::Parser::Files.find_template("mytemplate", environment).should be_nil
    end

    it "should accept relative templatedirs" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Puppet[:templatedir] = "my/templates"
      File.expects(:directory?).with(File.expand_path("my/templates")).returns(true)
      Puppet::Parser::Files.find_template("mytemplate", environment).should == File.expand_path("my/templates/mytemplate")
    end

    it "should use the environment templatedir if no module is found and an environment is specified" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Puppet::Parser::Files.stubs(:templatepath).with(environment).returns(["/myenv/templates"])
      Puppet::Parser::Files.find_template("mymod/mytemplate", environment).should == "/myenv/templates/mymod/mytemplate"
    end

    it "should use first dir from environment templatedir if no module is found and an environment is specified" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Puppet::Parser::Files.stubs(:templatepath).with(environment).returns(["/myenv/templates", "/two/templates"])
      Puppet::Parser::Files.find_template("mymod/mytemplate", environment).should == "/myenv/templates/mymod/mytemplate"
    end

    it "should use a valid dir when templatedir is a path for unqualified templates and the first dir contains template" do
      Puppet::Parser::Files.stubs(:templatepath).returns(["/one/templates", "/two/templates"])
      Puppet::FileSystem.expects(:exist?).with("/one/templates/mytemplate").returns(true)
      Puppet::Parser::Files.find_template("mytemplate", environment).should == "/one/templates/mytemplate"
    end

    it "should use a valid dir when templatedir is a path for unqualified templates and only second dir contains template" do
      Puppet::Parser::Files.stubs(:templatepath).returns(["/one/templates", "/two/templates"])
      Puppet::FileSystem.expects(:exist?).with("/one/templates/mytemplate").returns(false)
      Puppet::FileSystem.expects(:exist?).with("/two/templates/mytemplate").returns(true)
      Puppet::Parser::Files.find_template("mytemplate", environment).should == "/two/templates/mytemplate"
    end

    it "should use the node environment if specified" do
      mod = mock 'module'
      environment.expects(:module).with("mymod").returns mod

      mod.expects(:template).returns("/my/modules/mymod/templates/envtemplate")

      Puppet::Parser::Files.find_template("mymod/envtemplate", environment).should == "/my/modules/mymod/templates/envtemplate"
    end

    it "should return nil if no template can be found" do
      Puppet::Parser::Files.find_template("foomod/envtemplate", environment).should be_nil
    end
  end

  describe "when searching for manifests" do
    it "should ignore invalid modules" do
      mod = mock 'module'
      environment.expects(:module).with("mymod").raises(Puppet::Module::InvalidName, "name is invalid")
      Puppet.expects(:value).with(:modulepath).never
      Dir.stubs(:glob).returns %w{foo}

      Puppet::Parser::Files.find_manifests_in_modules("mymod/init.pp", environment)
    end
  end

  describe "when searching for manifests in a module" do
    def a_module_in_environment(env, name)
      mod = Puppet::Module.new(name, "/one/#{name}", env)
      env.stubs(:module).with(name).returns mod
      mod.stubs(:match_manifests).with("init.pp").returns(["/one/#{name}/manifests/init.pp"])
    end

    it "returns no files when no module is found" do
      module_name, files = Puppet::Parser::Files.find_manifests_in_modules("not_here_module/foo", environment)
      expect(files).to be_empty
      expect(module_name).to be_nil
    end

    it "should return the name of the module and the manifests from the first found module" do
      a_module_in_environment(environment, "mymod")

      Puppet::Parser::Files.find_manifests_in_modules("mymod/init.pp", environment).should ==
        ["mymod", ["/one/mymod/manifests/init.pp"]]
    end

    it "does not find the module when it is a different environment" do
      different_env = Puppet::Node::Environment.create(:different, [])
      a_module_in_environment(environment, "mymod")

      Puppet::Parser::Files.find_manifests_in_modules("mymod/init.pp", different_env).should_not include("mymod")
    end
  end
end
