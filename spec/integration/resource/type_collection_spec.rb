#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet/resource/type_collection'

describe Puppet::Resource::TypeCollection do
  describe "when autoloading from modules" do
    include PuppetSpec::Files

    before do
      @dir = tmpfile("autoload_testing")
      FileUtils.mkdir_p @dir

      loader = Object.new
      loader.stubs(:load).returns nil
      loader.stubs(:set_entry)

      loaders = Object.new
      loaders.expects(:runtime3_type_loader).at_most_once.returns loader
      Puppet::Pops::Loaders.expects(:loaders).at_most_once.returns loaders

      environment = Puppet::Node::Environment.create(:env, [@dir])
      @code = environment.known_resource_types
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
      expect(@code.find_hostclass('nosuchclass')).to be_nil
    end

    it "should load the module's init file first" do
      name = "simple"
      mk_module(name, :init => [name])
      expect(@code.find_hostclass(name).name).to eq(name)
    end

    it "should be able to load definitions from the module base file" do
      name = "simpdef"
      mk_module(name, :define => true, :init => [name])
      expect(@code.find_definition(name).name).to eq(name)
    end

    it "should be able to load qualified classes from the module base file" do
      mk_module('both', :init => %w{both both::sub})
      expect(@code.find_hostclass("both::sub").name).to eq("both::sub")
    end

    it "should be able load classes from a separate file" do
      mk_module('separate', :init => %w{separate}, :sub => %w{separate::sub})
      expect(@code.find_hostclass("separate::sub").name).to eq("separate::sub")
    end

    it "should not fail when loading from a separate file if there is no module file" do
      mk_module('alone', :sub => %w{alone::sub})
      expect { @code.find_hostclass("alone::sub") }.not_to raise_error
    end

    it "should be able to load definitions from their own file" do
      name = "mymod"
      mk_module(name, :define => true, :mydefine => ["mymod::mydefine"])
      expect(@code.find_definition("mymod::mydefine").name).to eq("mymod::mydefine")
    end

    it 'should be able to load definitions from their own file using uppercased name' do
      name = 'mymod'
      mk_module(name, :define => true, :mydefine => ['mymod::mydefine'])
      expect(@code.find_definition('Mymod::Mydefine')).not_to be_nil
    end
  end
end
