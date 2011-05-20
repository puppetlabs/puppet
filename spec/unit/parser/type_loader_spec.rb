#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parser/type_loader'
require 'puppet_spec/files'

describe Puppet::Parser::TypeLoader do
  include PuppetSpec::Files

  before do
    @loader = Puppet::Parser::TypeLoader.new(:myenv)
  end

  it "should support an environment" do
    loader = Puppet::Parser::TypeLoader.new(:myenv)
    loader.environment.name.should == :myenv
  end

  it "should include the Environment Helper" do
    @loader.class.ancestors.should be_include(Puppet::Node::Environment::Helper)
  end

  it "should delegate its known resource types to its environment" do
    @loader.known_resource_types.should be_instance_of(Puppet::Resource::TypeCollection)
  end

  describe "when loading names from namespaces" do
    it "should do nothing if the name to import is an empty string" do
      @loader.expects(:name2files).never
      @loader.try_load_fqname(:hostclass, "") { |filename, modname| raise :should_not_occur }.should be_nil
    end

    it "should attempt to import each generated name" do
      @loader.expects(:import).with("foo/bar",nil).returns([])
      @loader.expects(:import).with("foo",nil).returns([])
      @loader.try_load_fqname(:hostclass, "foo::bar") { |f| false }
    end
  end

  describe "when importing" do
    before do
      Puppet::Parser::Files.stubs(:find_manifests).returns ["modname", %w{file}]
      Puppet::Parser::Parser.any_instance.stubs(:parse).returns(Puppet::Parser::AST::Hostclass.new(''))
      Puppet::Parser::Parser.any_instance.stubs(:file=)
    end

    it "should return immediately when imports are being ignored" do
      Puppet::Parser::Files.expects(:find_manifests).never
      Puppet[:ignoreimport] = true
      @loader.import("foo").should be_nil
    end

    it "should find all manifests matching the file or pattern" do
      Puppet::Parser::Files.expects(:find_manifests).with { |pat, opts| pat == "myfile" }.returns ["modname", %w{one}]
      @loader.import("myfile")
    end

    it "should use the directory of the current file if one is set" do
      Puppet::Parser::Files.expects(:find_manifests).with { |pat, opts| opts[:cwd] == "/current" }.returns ["modname", %w{one}]
      @loader.import("myfile", "/current/file")
    end

    it "should pass the environment when looking for files" do
      Puppet::Parser::Files.expects(:find_manifests).with { |pat, opts| opts[:environment] == @loader.environment }.returns ["modname", %w{one}]
      @loader.import("myfile")
    end

    it "should fail if no files are found" do
      Puppet::Parser::Files.expects(:find_manifests).returns [nil, []]
      lambda { @loader.import("myfile") }.should raise_error(Puppet::ImportError)
    end

    it "should parse each found file" do
      Puppet::Parser::Files.expects(:find_manifests).returns ["modname", %w{/one}]
      @loader.expects(:parse_file).with("/one").returns(Puppet::Parser::AST::Hostclass.new(''))
      @loader.import("myfile")
    end

    it "should make each file qualified before attempting to parse it" do
      Puppet::Parser::Files.expects(:find_manifests).returns ["modname", %w{one}]
      @loader.expects(:parse_file).with("/current/one").returns(Puppet::Parser::AST::Hostclass.new(''))
      @loader.import("myfile", "/current/file")
    end

    it "should not attempt to import files that have already been imported" do
      Puppet::Parser::Files.expects(:find_manifests).returns ["modname", %w{/one}]
      Puppet::Parser::Parser.any_instance.expects(:parse).once.returns(Puppet::Parser::AST::Hostclass.new(''))
      @loader.import("myfile")

      # This will fail if it tries to reimport the file.
      @loader.import("myfile")
    end
  end

  describe "when importing all" do
    before do
      @base = tmpdir("base")

      # Create two module path directories
      @modulebase1 = File.join(@base, "first")
      FileUtils.mkdir_p(@modulebase1)
      @modulebase2 = File.join(@base, "second")
      FileUtils.mkdir_p(@modulebase2)

      Puppet[:modulepath] = "#{@modulebase1}:#{@modulebase2}"
    end

    def mk_module(basedir, name)
      module_dir = File.join(basedir, name)

      # Go ahead and make our manifest directory
      FileUtils.mkdir_p(File.join(module_dir, "manifests"))

      return Puppet::Module.new(name)
    end

    # We have to pass the base path so that we can
    # write to modules that are in the second search path
    def mk_manifests(base, mod, type, files)
      exts = {"ruby" => ".rb", "puppet" => ".pp"}
      files.collect do |file|
        name = mod.name + "::" + file.gsub("/", "::")
        path = File.join(base, mod.name, "manifests", file + exts[type])
        FileUtils.mkdir_p(File.split(path)[0])

        # write out the class
        if type == "ruby"
          File.open(path, "w") { |f| f.print "hostclass '#{name}' do\nend" }
        else
          File.open(path, "w") { |f| f.print "class #{name} {}" }
        end
        name
      end
    end

    it "should load all puppet manifests from all modules in the specified environment" do
      @module1 = mk_module(@modulebase1, "one")
      @module2 = mk_module(@modulebase2, "two")

      mk_manifests(@modulebase1, @module1, "puppet", %w{a b})
      mk_manifests(@modulebase2, @module2, "puppet", %w{c d})

      @loader.import_all

      @loader.environment.known_resource_types.hostclass("one::a").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("one::b").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("two::c").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("two::d").should be_instance_of(Puppet::Resource::Type)
    end

    it "should load all ruby manifests from all modules in the specified environment" do
      @module1 = mk_module(@modulebase1, "one")
      @module2 = mk_module(@modulebase2, "two")

      mk_manifests(@modulebase1, @module1, "ruby", %w{a b})
      mk_manifests(@modulebase2, @module2, "ruby", %w{c d})

      @loader.import_all

      @loader.environment.known_resource_types.hostclass("one::a").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("one::b").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("two::c").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("two::d").should be_instance_of(Puppet::Resource::Type)
    end

    it "should not load manifests from duplicate modules later in the module path" do
      @module1 = mk_module(@modulebase1, "one")

      # duplicate
      @module2 = mk_module(@modulebase2, "one")

      mk_manifests(@modulebase1, @module1, "puppet", %w{a})
      mk_manifests(@modulebase2, @module2, "puppet", %w{c})

      @loader.import_all

      @loader.environment.known_resource_types.hostclass("one::c").should be_nil
    end

    it "should load manifests from subdirectories" do
      @module1 = mk_module(@modulebase1, "one")

      mk_manifests(@modulebase1, @module1, "puppet", %w{a a/b a/b/c})

      @loader.import_all

      @loader.environment.known_resource_types.hostclass("one::a::b").should be_instance_of(Puppet::Resource::Type)
      @loader.environment.known_resource_types.hostclass("one::a::b::c").should be_instance_of(Puppet::Resource::Type)
    end
  end

  describe "when parsing a file" do
    before do
      @parser = Puppet::Parser::Parser.new(@loader.environment)
      @parser.stubs(:parse).returns(Puppet::Parser::AST::Hostclass.new(''))
      @parser.stubs(:file=)
      Puppet::Parser::Parser.stubs(:new).with(@loader.environment).returns @parser
    end

    it "should create a new parser instance for each file using the current environment" do
      Puppet::Parser::Parser.expects(:new).with(@loader.environment).returns @parser
      @loader.parse_file("/my/file")
    end

    it "should assign the parser its file and parse" do
      @parser.expects(:file=).with("/my/file")
      @parser.expects(:parse).returns(Puppet::Parser::AST::Hostclass.new(''))
      @loader.parse_file("/my/file")
    end
  end

  it "should be able to add classes to the current resource type collection" do
    file = tmpfile("simple_file.pp")
    File.open(file, "w") { |f| f.puts "class foo {}" }
    @loader.import(file)

    @loader.known_resource_types.hostclass("foo").should be_instance_of(Puppet::Resource::Type)
  end

  describe "when deciding where to look for files" do
    { 'foo' => ['foo'],
      'foo::bar' => ['foo/bar', 'foo'],
      'foo::bar::baz' => ['foo/bar/baz', 'foo/bar', 'foo']
    }.each do |fqname, expected_paths|
      it "should look for #{fqname.inspect} in #{expected_paths.inspect}" do
        @loader.instance_eval { name2files(fqname) }.should == expected_paths
      end
    end
  end
end
