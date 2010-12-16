#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'puppet/node/environment'
require 'puppet/util/execution'

describe Puppet::Node::Environment do
  after do
    Puppet::Node::Environment.clear
  end

  it "should include the Cacher module" do
    Puppet::Node::Environment.ancestors.should be_include(Puppet::Util::Cacher)
  end

  it "should use the filetimeout for the ttl for the modulepath" do
    Puppet::Node::Environment.attr_ttl(:modulepath).should == Integer(Puppet[:filetimeout])
  end

  it "should use the filetimeout for the ttl for the module list" do
    Puppet::Node::Environment.attr_ttl(:modules).should == Integer(Puppet[:filetimeout])
  end

  it "should use the filetimeout for the ttl for the manifestdir" do
    Puppet::Node::Environment.attr_ttl(:manifestdir).should == Integer(Puppet[:filetimeout])
  end

  it "should use the default environment if no name is provided while initializing an environment" do
    Puppet.settings.expects(:value).with(:environment).returns("one")
    Puppet::Node::Environment.new.name.should == :one
  end

  it "should treat environment instances as singletons" do
    Puppet::Node::Environment.new("one").should equal(Puppet::Node::Environment.new("one"))
  end

  it "should treat an environment specified as names or strings as equivalent" do
    Puppet::Node::Environment.new(:one).should equal(Puppet::Node::Environment.new("one"))
  end

  it "should return its name when converted to a string" do
    Puppet::Node::Environment.new(:one).to_s.should == "one"
  end

  it "should just return any provided environment if an environment is provided as the name" do
    one = Puppet::Node::Environment.new(:one)
    Puppet::Node::Environment.new(one).should equal(one)
  end

  describe "when managing known resource types" do
    before do
      @env = Puppet::Node::Environment.new("dev")
      @collection = Puppet::Resource::TypeCollection.new(@env)
      @env.stubs(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
      Thread.current[:known_resource_types] = nil
    end

    it "should create a resource type collection if none exists" do
      Puppet::Resource::TypeCollection.expects(:new).with(@env).returns @collection
      @env.known_resource_types.should equal(@collection)
    end

    it "should reuse any existing resource type collection" do
      @env.known_resource_types.should equal(@env.known_resource_types)
    end

    it "should perform the initial import when creating a new collection" do
      @env = Puppet::Node::Environment.new("dev")
      @env.expects(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
      @env.known_resource_types
    end

    it "should return the same collection even if stale if it's the same thread" do
      Puppet::Resource::TypeCollection.stubs(:new).returns @collection
      @env.known_resource_types.stubs(:stale?).returns true

      @env.known_resource_types.should equal(@collection)
    end

    it "should return the current thread associated collection if there is one" do
      Thread.current[:known_resource_types] = @collection

      @env.known_resource_types.should equal(@collection)
    end

    it "should give to all threads the same collection if it didn't change" do
      Puppet::Resource::TypeCollection.expects(:new).with(@env).returns @collection
      @env.known_resource_types

      t = Thread.new {
        @env.known_resource_types.should equal(@collection)
      }
      t.join
    end

    it "should give to new threads a new collection if it isn't stale" do
      Puppet::Resource::TypeCollection.expects(:new).with(@env).returns @collection
      @env.known_resource_types.expects(:stale?).returns(true)

      Puppet::Resource::TypeCollection.expects(:new).returns @collection

      t = Thread.new {
        @env.known_resource_types.should equal(@collection)
      }
      t.join
    end

  end

  [:modulepath, :manifestdir].each do |setting|
    it "should validate the #{setting} directories" do
      path = %w{/one /two}.join(File::PATH_SEPARATOR)

      env = Puppet::Node::Environment.new("testing")
      env.stubs(:[]).with(setting).returns path

      env.expects(:validate_dirs).with(%w{/one /two})

      env.send(setting)
    end

    it "should return the validated dirs for #{setting}" do
      path = %w{/one /two}.join(File::PATH_SEPARATOR)

      env = Puppet::Node::Environment.new("testing")
      env.stubs(:[]).with(setting).returns path
      env.stubs(:validate_dirs).returns %w{/one /two}

      env.send(setting).should == %w{/one /two}
    end
  end

  it "should prefix the value of the 'PUPPETLIB' environment variable to the module path if present" do
    Puppet::Util::Execution.withenv("PUPPETLIB" => %w{/l1 /l2}.join(File::PATH_SEPARATOR)) do
      env = Puppet::Node::Environment.new("testing")
      module_path = %w{/one /two}.join(File::PATH_SEPARATOR)
      env.expects(:validate_dirs).with(%w{/l1 /l2 /one /two}).returns %w{/l1 /l2 /one /two}
      env.expects(:[]).with(:modulepath).returns module_path

      env.modulepath.should == %w{/l1 /l2 /one /two}
    end
  end

  describe "when validating modulepath or manifestdir directories" do
    it "should not return non-directories" do
      env = Puppet::Node::Environment.new("testing")

      FileTest.expects(:directory?).with("/one").returns true
      FileTest.expects(:directory?).with("/two").returns false

      env.validate_dirs(%w{/one /two}).should == %w{/one}
    end

    it "should use the current working directory to fully-qualify unqualified paths" do
      FileTest.stubs(:directory?).returns true
      env = Puppet::Node::Environment.new("testing")

      two = File.join(Dir.getwd, "two")
      env.validate_dirs(%w{/one two}).should == ["/one", two]
    end
  end

  describe "when modeling a specific environment" do
    it "should have a method for returning the environment name" do
      Puppet::Node::Environment.new("testing").name.should == :testing
    end

    it "should provide an array-like accessor method for returning any environment-specific setting" do
      env = Puppet::Node::Environment.new("testing")
      env.should respond_to(:[])
    end

    it "should ask the Puppet settings instance for the setting qualified with the environment name" do
      Puppet.settings.expects(:value).with("myvar", :testing).returns("myval")
      env = Puppet::Node::Environment.new("testing")
      env["myvar"].should == "myval"
    end

    it "should be able to return an individual module that exists in its module path" do
      env = Puppet::Node::Environment.new("testing")

      mod = mock 'module'
      Puppet::Module.expects(:new).with("one", env).returns mod
      mod.expects(:exist?).returns true

      env.module("one").should equal(mod)
    end

    it "should return nil if asked for a module that does not exist in its path" do
      env = Puppet::Node::Environment.new("testing")

      mod = mock 'module'
      Puppet::Module.expects(:new).with("one", env).returns mod
      mod.expects(:exist?).returns false

      env.module("one").should be_nil
    end

    it "should be able to return its modules" do
      Puppet::Node::Environment.new("testing").should respond_to(:modules)
    end

    describe ".modules" do
      it "should return a module named for every directory in each module path" do
        env = Puppet::Node::Environment.new("testing")
        env.expects(:modulepath).at_least_once.returns %w{/a /b}
        Dir.expects(:entries).with("/a").returns %w{foo bar}
        Dir.expects(:entries).with("/b").returns %w{bee baz}

        env.modules.collect{|mod| mod.name}.sort.should == %w{foo bar bee baz}.sort
      end

      it "should remove duplicates" do
        env = Puppet::Node::Environment.new("testing")
        env.expects(:modulepath).returns( %w{/a /b} ).at_least_once
        Dir.expects(:entries).with("/a").returns %w{foo}
        Dir.expects(:entries).with("/b").returns %w{foo}

        env.modules.collect{|mod| mod.name}.sort.should == %w{foo}
      end

      it "should ignore invalid modules" do
        env = Puppet::Node::Environment.new("testing")
        env.stubs(:modulepath).returns %w{/a}
        Dir.expects(:entries).with("/a").returns %w{foo bar}

        Puppet::Module.expects(:new).with { |name, env| name == "foo" }.returns mock("foomod", :name => "foo")
        Puppet::Module.expects(:new).with { |name, env| name == "bar" }.raises( Puppet::Module::InvalidName, "name is invalid" )

        env.modules.collect{|mod| mod.name}.sort.should == %w{foo}
      end

      it "should create modules with the correct environment" do
        env = Puppet::Node::Environment.new("testing")
        env.expects(:modulepath).at_least_once.returns %w{/a}
        Dir.expects(:entries).with("/a").returns %w{foo}

        env.modules.each {|mod| mod.environment.should == env }
      end

      it "should cache the module list" do
        env = Puppet::Node::Environment.new("testing")
        env.expects(:modulepath).at_least_once.returns %w{/a}
        Dir.expects(:entries).once.with("/a").returns %w{foo}

        env.modules
        env.modules
      end
    end
  end

  describe Puppet::Node::Environment::Helper do
    before do
      @helper = Object.new
      @helper.extend(Puppet::Node::Environment::Helper)
    end

    it "should be able to set and retrieve the environment" do
      @helper.environment = :foo
      @helper.environment.name.should == :foo
    end

    it "should accept an environment directly" do
      env = Puppet::Node::Environment.new :foo
      @helper.environment = env
      @helper.environment.name.should == :foo
    end

    it "should accept an environment as a string" do
      env = Puppet::Node::Environment.new "foo"
      @helper.environment = env
      @helper.environment.name.should == :foo
    end
  end

  describe "when performing initial import" do
    before do
      @parser = stub 'parser', :file= => nil, :string => nil, :parse => nil
      Puppet::Parser::Parser.stubs(:new).returns @parser
      @env = Puppet::Node::Environment.new("env")
    end

    it "should create a new parser instance" do
      Puppet::Parser::Parser.expects(:new).returns @parser
      @env.instance_eval { perform_initial_import }
    end

    it "should set the parser's string to the 'code' setting and parse if code is available" do
      Puppet.settings[:code] = "my code"
      @parser.expects(:string=).with "my code"
      @parser.expects(:parse)
      @env.instance_eval { perform_initial_import }
    end

    it "should set the parser's file to the 'manifest' setting and parse if no code is available and the manifest is available" do
      File.stubs(:expand_path).with("/my/file").returns "/my/file"
      File.expects(:exist?).with("/my/file").returns true
      Puppet.settings[:manifest] = "/my/file"
      @parser.expects(:file=).with "/my/file"
      @parser.expects(:parse)
      @env.instance_eval { perform_initial_import }
    end

    it "should not attempt to load a manifest if none is present" do
      File.stubs(:expand_path).with("/my/file").returns "/my/file"
      File.expects(:exist?).with("/my/file").returns false
      Puppet.settings[:manifest] = "/my/file"
      @parser.expects(:file=).never
      @parser.expects(:parse).never
      @env.instance_eval { perform_initial_import }
    end

    it "should fail helpfully if there is an error importing" do
      File.stubs(:exist?).returns true
      @parser.expects(:parse).raises ArgumentError
      lambda { @env.instance_eval { perform_initial_import } }.should raise_error(Puppet::Error)
    end

    it "should not do anything if the ignore_import settings is set" do
      Puppet.settings[:ignoreimport] = true
      @parser.expects(:string=).never
      @parser.expects(:file=).never
      @parser.expects(:parse).never
      @env.instance_eval { perform_initial_import }
    end
  end
end
