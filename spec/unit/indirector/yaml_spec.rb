#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/yaml'

describe Puppet::Indirector::Yaml do
  include PuppetSpec::Files

  before(:all) do
    class Puppet::YamlTestModel
      extend Puppet::Indirector
      indirects :yaml_test_model
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class Puppet::YamlTestModel::Yaml < Puppet::Indirector::Yaml; end

    Puppet::YamlTestModel.indirection.terminus_class = :yaml
  end

  after(:all) do
    Puppet::YamlTestModel.indirection.delete
    Puppet.send(:remove_const, :YamlTestModel)
  end

  let(:model) { Puppet::YamlTestModel }
  let(:subject) { model.new(:me) }
  let(:indirection) { model.indirection }
  let(:terminus) { indirection.terminus(:yaml) }

  let(:dir) { tmpdir("yaml_indirector") }
  let(:indirection_dir) { File.join(dir, indirection.name.to_s) }
  let(:serverdir) { File.expand_path("/server/yaml/dir") }
  let(:clientdir) { File.expand_path("/client/yaml/dir") }

  before :each do
    Puppet[:clientyamldir] = dir
    Puppet.run_mode.stubs(:master?).returns false
  end

  describe "when choosing file location" do
    it "should use the server_datadir if the run_mode is master" do
      Puppet.run_mode.stubs(:master?).returns true
      Puppet[:yamldir] = serverdir
      expect(terminus.path(:me)).to match(/^#{serverdir}/)
    end

    it "should use the client yamldir if the run_mode is not master" do
      Puppet.run_mode.stubs(:master?).returns false
      Puppet[:clientyamldir] = clientdir
      expect(terminus.path(:me)).to match(/^#{clientdir}/)
    end

    it "should use the extension if one is specified" do
      Puppet.run_mode.stubs(:master?).returns true
      Puppet[:yamldir] = serverdir
      expect(terminus.path(:me,'.farfignewton')).to match(%r{\.farfignewton$})
    end

    it "should assume an extension of .yaml if none is specified" do
      Puppet.run_mode.stubs(:master?).returns true
      Puppet[:yamldir] = serverdir
      expect(terminus.path(:me)).to match(%r{\.yaml$})
    end

    it "should store all files in a single file root set in the Puppet defaults" do
      expect(terminus.path(:me)).to match(%r{^#{dir}})
    end

    it "should use the terminus name for choosing the subdirectory" do
      expect(terminus.path(:me)).to match(%r{^#{dir}/yaml_test_model})
    end

    it "should use the object's name to determine the file name" do
      expect(terminus.path(:me)).to match(%r{me.yaml$})
    end

    ['../foo', '..\\foo', './../foo', '.\\..\\foo',
     '/foo', '//foo', '\\foo', '\\\\goo',
     "test\0/../bar", "test\0\\..\\bar",
     "..\\/bar", "/tmp/bar", "/tmp\\bar", "tmp\\bar",
     " / bar", " /../ bar", " \\..\\ bar",
     "c:\\foo", "c:/foo", "\\\\?\\UNC\\bar", "\\\\foo\\bar",
     "\\\\?\\c:\\foo", "//?/UNC/bar", "//foo/bar",
     "//?/c:/foo",
    ].each do |input|
      it "should resist directory traversal attacks (#{input.inspect})" do
        expect { terminus.path(input) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "when storing objects as YAML" do
    it "should only store objects that respond to :name" do
      request = indirection.request(:save, "testing", Object.new)
      expect { terminus.save(request) }.to raise_error(ArgumentError)
    end
  end

  describe "when retrieving YAML" do
    it "should read YAML in from disk and convert it to Ruby objects" do
      terminus.save(indirection.request(:save, "testing", subject))
      yaml = terminus.find(indirection.request(:find, "testing", nil))
      expect(yaml.name).to eq(:me)
    end

    it "should fail coherently when the stored YAML is invalid" do
      terminus.save(indirection.request(:save, "testing", subject))
      # overwrite file
      File.open(terminus.path('testing'), "w") do |file|
        file.puts "{ invalid"
      end

      expect {
        terminus.find(indirection.request(:find, "testing", nil))
      }.to raise_error(Puppet::Error, /Could not parse YAML data/)
    end
  end

  describe "when searching" do
    before :each do
      Puppet[:clientyamldir] = dir
    end

    def dir_containing_instances(instances)
      Dir.mkdir(indirection_dir)
      instances.each do |hash|
        File.open(File.join(indirection_dir, "#{hash['name']}.yaml"), 'wb') do |f|
          f.write(YAML.dump(hash))
        end
      end
    end

    it "should return an array of fact instances with one instance for each file when globbing *" do
      one = { 'name' => 'one', 'values' => { 'foo' => 'bar' } }
      two = { 'name' => 'two', 'values' => { 'foo' => 'baz' } }
      dir_containing_instances([one, two])

      request = indirection.request(:search, "*", nil)
      expect(terminus.search(request)).to contain_exactly(one, two)
    end

    it "should return an array containing a single instance of fact when globbing 'one*'" do
      one = { 'name' => 'one', 'values' => { 'foo' => 'bar' } }
      two = { 'name' => 'two', 'values' => { 'foo' => 'baz' } }
      dir_containing_instances([one, two])

      request = indirection.request(:search, "one*", nil)
      expect(terminus.search(request)).to eq([one])
    end

    it "should return an empty array when the glob doesn't match anything" do
      one = { 'name' => 'one', 'values' => { 'foo' => 'bar' } }
      dir_containing_instances([one])

      request = indirection.request(:search, "f*ilglobcanfail*", nil)
      expect(terminus.search(request)).to eq([])
    end

    describe "when destroying" do
      let(:path) { File.join(indirection_dir, "one.yaml") }

      before :each do
        Puppet[:clientyamldir] = dir

        one = { 'name' => 'one', 'values' => { 'foo' => 'bar' } }
        dir_containing_instances([one])
      end

      it "should unlink the right yaml file if it exists" do
        request = indirection.request(:destroy, "one", nil)
        terminus.destroy(request)

        expect(Puppet::FileSystem).to_not exist(path)
      end

      it "should not unlink the yaml file if it does not exists" do
        request = indirection.request(:destroy, "doesntexist", nil)
        terminus.destroy(request)

        expect(Puppet::FileSystem).to exist(path)
      end
    end
  end
end
