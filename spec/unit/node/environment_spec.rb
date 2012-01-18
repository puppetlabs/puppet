#!/usr/bin/env rspec
require 'spec_helper'

require 'tmpdir'

require 'puppet/node/environment'
require 'puppet/util/execution'

describe Puppet::Node::Environment do
  let(:env) { Puppet::Node::Environment.new("testing") }

  include PuppetSpec::Files
  after do
    Puppet::Node::Environment.clear
  end

  it "should use the filetimeout for the ttl for the modulepath" do
    Puppet::Node::Environment.attr_ttl(:modulepath).should == Integer(Puppet[:filetimeout])
  end

  it "should use the filetimeout for the ttl for the module list" do
    Puppet::Node::Environment.attr_ttl(:modules).should == Integer(Puppet[:filetimeout])
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
      @collection = Puppet::Resource::TypeCollection.new(env)
      env.stubs(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
      Thread.current[:known_resource_types] = nil
    end

    it "should create a resource type collection if none exists" do
      Puppet::Resource::TypeCollection.expects(:new).with(env).returns @collection
      env.known_resource_types.should equal(@collection)
    end

    it "should reuse any existing resource type collection" do
      env.known_resource_types.should equal(env.known_resource_types)
    end

    it "should perform the initial import when creating a new collection" do
      env.expects(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
      env.known_resource_types
    end

    it "should return the same collection even if stale if it's the same thread" do
      Puppet::Resource::TypeCollection.stubs(:new).returns @collection
      env.known_resource_types.stubs(:stale?).returns true

      env.known_resource_types.should equal(@collection)
    end

    it "should return the current thread associated collection if there is one" do
      Thread.current[:known_resource_types] = @collection

      env.known_resource_types.should equal(@collection)
    end

    it "should give to all threads using the same environment the same collection if the collection isn't stale" do
      original_thread_type_collection = Puppet::Resource::TypeCollection.new(env)
      Puppet::Resource::TypeCollection.expects(:new).with(env).returns original_thread_type_collection
      env.known_resource_types.should equal(original_thread_type_collection)

      original_thread_type_collection.expects(:require_reparse?).returns(false)
      Puppet::Resource::TypeCollection.stubs(:new).with(env).returns @collection

      t = Thread.new {
        env.known_resource_types.should equal(original_thread_type_collection)
      }
      t.join
    end

    it "should generate a new TypeCollection if the current one requires reparsing" do
      old_type_collection = env.known_resource_types
      old_type_collection.stubs(:require_reparse?).returns true
      Thread.current[:known_resource_types] = nil
      new_type_collection = env.known_resource_types

      new_type_collection.should be_a Puppet::Resource::TypeCollection
      new_type_collection.should_not equal(old_type_collection)
    end
  end

  it "should validate the modulepath directories" do
    real_file = tmpdir('moduledir')
    path = %W[/one /two #{real_file}].join(File::PATH_SEPARATOR)

    Puppet[:modulepath] = path

    env.modulepath.should == [real_file]
  end

  it "should prefix the value of the 'PUPPETLIB' environment variable to the module path if present" do
    Puppet::Util::Execution.withenv("PUPPETLIB" => %w{/l1 /l2}.join(File::PATH_SEPARATOR)) do
      module_path = %w{/one /two}.join(File::PATH_SEPARATOR)
      env.expects(:validate_dirs).with(%w{/l1 /l2 /one /two}).returns %w{/l1 /l2 /one /two}
      env.expects(:[]).with(:modulepath).returns module_path

      env.modulepath.should == %w{/l1 /l2 /one /two}
    end
  end

  describe "when validating modulepath or manifestdir directories" do
    before :each do
      @path_one = make_absolute('/one')
      @path_two = make_absolute('/two')
    end

    it "should not return non-directories" do
      FileTest.expects(:directory?).with(@path_one).returns true
      FileTest.expects(:directory?).with(@path_two).returns false

      env.validate_dirs([@path_one, @path_two]).should == [@path_one]
    end

    it "should use the current working directory to fully-qualify unqualified paths" do
      FileTest.stubs(:directory?).returns true

      two = File.expand_path(File.join(Dir.getwd, "two"))
      env.validate_dirs([@path_one, 'two']).should == [@path_one, two]
    end
  end

  describe "when modeling a specific environment" do
    it "should have a method for returning the environment name" do
      Puppet::Node::Environment.new("testing").name.should == :testing
    end

    it "should provide an array-like accessor method for returning any environment-specific setting" do
      env.should respond_to(:[])
    end

    it "should ask the Puppet settings instance for the setting qualified with the environment name" do
      Puppet.settings.expects(:value).with("myvar", :testing).returns("myval")
      env["myvar"].should == "myval"
    end

    it "should be able to return an individual module that exists in its module path" do

      mod = mock 'module'
      Puppet::Module.expects(:new).with("one", :environment => env).returns mod
      mod.expects(:exist?).returns true

      env.module("one").should equal(mod)
    end

    it "should return nil if asked for a module that does not exist in its path" do

      mod = mock 'module'
      Puppet::Module.expects(:new).with("one", :environment => env).returns mod
      mod.expects(:exist?).returns false

      env.module("one").should be_nil
    end

    describe ".modules_by_path" do
      before do
        dir = tmpdir("deep_path")

        @first = File.join(dir, "first")
        @second = File.join(dir, "second")
        Puppet[:modulepath] = "#{@first}#{File::PATH_SEPARATOR}#{@second}"

        FileUtils.mkdir_p(@first)
        FileUtils.mkdir_p(@second)
      end

      it "should return an empty list if there are no modules" do
        env.modules_by_path.should == {
          @first  => [],
          @second => []
        }
      end

      it "should include modules even if they exist in multiple dirs in the modulepath" do
        modpath1 = File.join(@first, "foo")
        FileUtils.mkdir_p(modpath1)
        modpath2 = File.join(@second, "foo")
        FileUtils.mkdir_p(modpath2)

        env.modules_by_path.should == {
          @first  => [Puppet::Module.new('foo', :environment => env, :path => modpath1)],
          @second => [Puppet::Module.new('foo', :environment => env, :path => modpath2)]
        }
      end
    end

    describe ".modules" do
      it "should return an empty list if there are no modules" do
        env.modulepath = %w{/a /b}
        Dir.expects(:entries).with("/a").returns []
        Dir.expects(:entries).with("/b").returns []

        env.modules.should == []
      end

      it "should return a module named for every directory in each module path" do
        env.modulepath = %w{/a /b}
        Dir.expects(:entries).with("/a").returns %w{foo bar}
        Dir.expects(:entries).with("/b").returns %w{bee baz}

        env.modules.collect{|mod| mod.name}.sort.should == %w{foo bar bee baz}.sort
      end

      it "should remove duplicates" do
        env.modulepath = %w{/a /b}
        Dir.expects(:entries).with("/a").returns %w{foo}
        Dir.expects(:entries).with("/b").returns %w{foo}

        env.modules.collect{|mod| mod.name}.sort.should == %w{foo}
      end

      it "should ignore invalid modules" do
        env.modulepath = %w{/a}
        Dir.expects(:entries).with("/a").returns %w{foo bar}

        Puppet::Module.expects(:new).with { |name, env| name == "foo" }.returns mock("foomod", :name => "foo")
        Puppet::Module.expects(:new).with { |name, env| name == "bar" }.raises( Puppet::Module::InvalidName, "name is invalid" )

        env.modules.collect{|mod| mod.name}.sort.should == %w{foo}
      end

      it "should create modules with the correct environment" do
        env.modulepath = %w{/a}
        Dir.expects(:entries).with("/a").returns %w{foo}

        env.modules.each {|mod| mod.environment.should == env }
      end

      it "should cache the module list" do
        env.modulepath = %w{/a}
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

    it "should be able to set and retrieve the environment as a symbol" do
      @helper.environment = :foo
      @helper.environment.name.should == :foo
    end

    it "should accept an environment directly" do
      @helper.environment = Puppet::Node::Environment.new(:foo)
      @helper.environment.name.should == :foo
    end

    it "should accept an environment as a string" do
      @helper.environment = 'foo'
      @helper.environment.name.should == :foo
    end
  end

  describe "when performing initial import" do
    before do
      @parser = Puppet::Parser::Parser.new("test")
      Puppet::Parser::Parser.stubs(:new).returns @parser
    end

    it "should set the parser's string to the 'code' setting and parse if code is available" do
      Puppet.settings[:code] = "my code"
      @parser.expects(:string=).with "my code"
      @parser.expects(:parse)
      env.instance_eval { perform_initial_import }
    end

    it "should set the parser's file to the 'manifest' setting and parse if no code is available and the manifest is available" do
      filename = tmpfile('myfile')
      File.open(filename, 'w'){|f| }
      Puppet.settings[:manifest] = filename
      @parser.expects(:file=).with filename
      @parser.expects(:parse)
      env.instance_eval { perform_initial_import }
    end

    it "should pass the manifest file to the parser even if it does not exist on disk" do
      filename = tmpfile('myfile')
      Puppet.settings[:code] = ""
      Puppet.settings[:manifest] = filename
      @parser.expects(:file=).with(filename).once
      @parser.expects(:parse).once
      env.instance_eval { perform_initial_import }
    end

    it "should fail helpfully if there is an error importing" do
      File.stubs(:exist?).returns true
      env.stubs(:known_resource_types).returns Puppet::Resource::TypeCollection.new(env)
      @parser.expects(:file=).once
      @parser.expects(:parse).raises ArgumentError
      lambda { env.instance_eval { perform_initial_import } }.should raise_error(Puppet::Error)
    end

    it "should not do anything if the ignore_import settings is set" do
      Puppet.settings[:ignoreimport] = true
      @parser.expects(:string=).never
      @parser.expects(:file=).never
      @parser.expects(:parse).never
      env.instance_eval { perform_initial_import }
    end

    it "should mark the type collection as needing a reparse when there is an error parsing" do
      @parser.expects(:parse).raises Puppet::ParseError.new("Syntax error at ...")
      env.stubs(:known_resource_types).returns Puppet::Resource::TypeCollection.new(env)

      lambda { env.instance_eval { perform_initial_import } }.should raise_error(Puppet::Error, /Syntax error at .../)
      env.known_resource_types.require_reparse?.should be_true
    end
  end
end
