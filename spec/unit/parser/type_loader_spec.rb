#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parser/type_loader'
require 'puppet/parser/parser_factory'
require 'puppet_spec/modules'
require 'puppet_spec/files'

describe Puppet::Parser::TypeLoader do
  include PuppetSpec::Modules
  include PuppetSpec::Files

  let(:empty_hostclass) { Puppet::Parser::AST::Hostclass.new('') }
  let(:loader) { Puppet::Parser::TypeLoader.new(:myenv) }

  it "should support an environment" do
    loader = Puppet::Parser::TypeLoader.new(:myenv)
    loader.environment.name.should == :myenv
  end

  it "should delegate its known resource types to its environment" do
    loader.known_resource_types.should be_instance_of(Puppet::Resource::TypeCollection)
  end

  describe "when loading names from namespaces" do
    it "should do nothing if the name to import is an empty string" do
      loader.try_load_fqname(:hostclass, "").should be_nil
    end

    it "should attempt to import each generated name" do
      loader.expects(:import_from_modules).with("foo/bar").returns([])
      loader.expects(:import_from_modules).with("foo").returns([])
      loader.try_load_fqname(:hostclass, "foo::bar")
    end

    it "should attempt to load each possible name going from most to least specific" do
      path_order = sequence('path')
      ['foo/bar/baz', 'foo/bar', 'foo'].each do |path|
        Puppet::Parser::Files.expects(:find_manifests_in_modules).with(path, anything).returns([nil, []]).in_sequence(path_order)
      end

      loader.try_load_fqname(:hostclass, 'foo::bar::baz')
    end
  end

  describe "when importing" do
    let(:stub_parser) { stub 'Parser', :file= => nil, :parse => empty_hostclass }

    before(:each) do
      Puppet::Parser::ParserFactory.stubs(:parser).with(anything).returns(stub_parser)
    end

    it "should return immediately when imports are being ignored" do
      Puppet::Parser::Files.expects(:find_manifests_in_modules).never
      Puppet[:ignoreimport] = true
      loader.import("foo", "/path").should be_nil
    end

    it "should find all manifests matching the file or pattern" do
      Puppet::Parser::Files.expects(:find_manifests_in_modules).with("myfile", anything).returns ["modname", %w{one}]
      loader.import("myfile", "/path")
    end

    it "should pass the environment when looking for files" do
      Puppet::Parser::Files.expects(:find_manifests_in_modules).with(anything, loader.environment).returns ["modname", %w{one}]
      loader.import("myfile", "/path")
    end

    it "should fail if no files are found" do
      Puppet::Parser::Files.expects(:find_manifests_in_modules).returns [nil, []]
      lambda { loader.import("myfile", "/path") }.should raise_error(Puppet::ImportError)
    end

    it "should parse each found file" do
      Puppet::Parser::Files.expects(:find_manifests_in_modules).returns ["modname", [make_absolute("/one")]]
      loader.expects(:parse_file).with(make_absolute("/one")).returns(Puppet::Parser::AST::Hostclass.new(''))
      loader.import("myfile", "/path")
    end

    it "should not attempt to import files that have already been imported" do
      loader = Puppet::Parser::TypeLoader.new(:myenv)

      Puppet::Parser::Files.expects(:find_manifests_in_modules).twice.returns ["modname", %w{/one}]
      loader.import("myfile", "/path").should_not be_empty

      loader.import("myfile", "/path").should be_empty
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

      Puppet[:modulepath] = "#{@modulebase1}#{File::PATH_SEPARATOR}#{@modulebase2}"
    end

    def mk_module(basedir, name)
      PuppetSpec::Modules.create(name, basedir)
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

      loader.import_all

      loader.environment.known_resource_types.hostclass("one::a").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("one::b").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("two::c").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("two::d").should be_instance_of(Puppet::Resource::Type)
    end

    it "should load all ruby manifests from all modules in the specified environment" do
      Puppet.expects(:deprecation_warning).at_least(1)

      @module1 = mk_module(@modulebase1, "one")
      @module2 = mk_module(@modulebase2, "two")

      mk_manifests(@modulebase1, @module1, "ruby", %w{a b})
      mk_manifests(@modulebase2, @module2, "ruby", %w{c d})

      loader.import_all

      loader.environment.known_resource_types.hostclass("one::a").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("one::b").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("two::c").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("two::d").should be_instance_of(Puppet::Resource::Type)
    end

    it "should not load manifests from duplicate modules later in the module path" do
      @module1 = mk_module(@modulebase1, "one")

      # duplicate
      @module2 = mk_module(@modulebase2, "one")

      mk_manifests(@modulebase1, @module1, "puppet", %w{a})
      mk_manifests(@modulebase2, @module2, "puppet", %w{c})

      loader.import_all

      loader.environment.known_resource_types.hostclass("one::c").should be_nil
    end

    it "should load manifests from subdirectories" do
      @module1 = mk_module(@modulebase1, "one")

      mk_manifests(@modulebase1, @module1, "puppet", %w{a a/b a/b/c})

      loader.import_all

      loader.environment.known_resource_types.hostclass("one::a::b").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("one::a::b::c").should be_instance_of(Puppet::Resource::Type)
    end

    it "should skip modules that don't have manifests" do
      @module1 = mk_module(@modulebase1, "one")
      @module2 = mk_module(@modulebase2, "two")
      mk_manifests(@modulebase2, @module2, "ruby", %w{c d})

      loader.import_all

      loader.environment.known_resource_types.hostclass("one::a").should be_nil
      loader.environment.known_resource_types.hostclass("two::c").should be_instance_of(Puppet::Resource::Type)
      loader.environment.known_resource_types.hostclass("two::d").should be_instance_of(Puppet::Resource::Type)
    end
  end

  describe "when parsing a file" do
    it "should create a new parser instance for each file using the current environment" do
      parser = stub 'Parser', :file= => nil, :parse => empty_hostclass

      Puppet::Parser::ParserFactory.expects(:parser).twice.with(loader.environment).returns(parser)

      loader.parse_file("/my/file")
      loader.parse_file("/my/other_file")
    end

    it "should assign the parser its file and parse" do
      parser = mock 'parser'

      Puppet::Parser::ParserFactory.expects(:parser).with(loader.environment).returns(parser)
      parser.expects(:file=).with("/my/file")
      parser.expects(:parse).returns(empty_hostclass)

      loader.parse_file("/my/file")
    end
  end

  it "should be able to add classes to the current resource type collection" do
    file = tmpfile("simple_file.pp")
    File.open(file, "w") { |f| f.puts "class foo {}" }
    loader.import(File.basename(file), File.dirname(file))

    loader.known_resource_types.hostclass("foo").should be_instance_of(Puppet::Resource::Type)
  end
end
