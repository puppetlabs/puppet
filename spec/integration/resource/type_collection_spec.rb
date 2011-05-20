#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet/resource/type_collection'

describe Puppet::Resource::TypeCollection do
  describe "when autoloading from modules" do
    include PuppetSpec::Files

    before do
      @dir = tmpfile("autoload_testing")
      Puppet[:modulepath] = @dir

      FileUtils.mkdir_p @dir
      @code = Puppet::Resource::TypeCollection.new("env")
      Puppet::Node::Environment.new("env").stubs(:known_resource_types).returns @code
    end

    # Setup a module.
    def mk_module(name, files = {})
      mdir = File.join(@dir, name)
      mandir = File.join(mdir, "manifests")
      FileUtils.mkdir_p mandir

      defs = files.delete(:define)

      Dir.chdir(mandir) do
        files.each do |file, classes|
          File.open("#{file}.pp", "w") do |f|
            classes.each { |klass|
              if defs
                f.puts "define #{klass} {}"
              else
                f.puts "class #{klass} {}"
              end
            }
          end
        end
      end
    end

    it "should return nil when a class can't be found or loaded" do
      @code.find_hostclass('', 'nosuchclass').should be_nil
    end

    it "should load the module's init file first" do
      name = "simple"
      mk_module(name, :init => [name])

      @code.find_hostclass("", name).name.should == name
    end

    it "should load the module's init file even when searching from a different namespace" do
      name = "simple"
      mk_module(name, :init => [name])

      @code.find_hostclass("other::ns", name).name.should == name
    end

    it "should be able to load definitions from the module base file" do
      name = "simpdef"
      mk_module(name, :define => true, :init => [name])
      @code.find_definition("", name).name.should == name
    end

    it "should be able to load qualified classes from the module base file" do
      modname = "both"
      name = "sub"
      mk_module(modname, :init => %w{both both::sub})

      @code.find_hostclass("both", name).name.should == "both::sub"
    end

    it "should be able load classes from a separate file" do
      modname = "separate"
      name = "sub"
      mk_module(modname, :init => %w{separate}, :sub => %w{separate::sub})
      @code.find_hostclass("separate", name).name.should == "separate::sub"
    end

    it "should not fail when loading from a separate file if there is no module file" do
      modname = "alone"
      name = "sub"
      mk_module(modname, :sub => %w{alone::sub})
      lambda { @code.find_hostclass("alone", name) }.should_not raise_error
    end

    it "should be able to load definitions from their own file" do
      name = "mymod"
      mk_module(name, :define => true, :mydefine => ["mymod::mydefine"])
      @code.find_definition("", "mymod::mydefine").name.should == "mymod::mydefine"
    end
  end
end
