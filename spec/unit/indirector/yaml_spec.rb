#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/yaml'

describe Puppet::Indirector::Yaml do
  include PuppetSpec::Files

  class TestSubject
    attr_accessor :name
    def initialize(name)
      @name = name
    end
  end

  before(:all) do
    class Puppet::YamlTestModel
      extend Puppet::Indirector
      indirects :yaml_test_model
    end

    class Puppet::YamlTestModel::Yaml < Puppet::Indirector::Yaml
      attr_accessor :name
      def initialize
        @name = :my_yaml
      end
    end

    Puppet::YamlTestModel.indirection.terminus_class = :yaml
  end

  after(:all) do
    Puppet::YamlTestModel.indirection.delete
    Puppet.send(:remove_const, :YamlTestModel)
  end

  let(:terminus) { Puppet::YamlTestModel.indirection.terminus(:yaml) }
  let(:indirection) { Puppet::YamlTestModel.indirection }
  let(:model) { Puppet::YamlTestModel }

  let(:subject) { TestSubject.new(:me) }
  let(:dir) { tmpdir("yaml_indirector") }
  let(:request) { stub('request', key: :me, instance: subject) }
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
      request.stubs(:instance).returns Object.new
      expect { terminus.save(request) }.to raise_error(ArgumentError)
    end
  end

  describe "when retrieving YAML" do
    it "should read YAML in from disk and convert it to Ruby objects" do
      terminus.save(Puppet::Indirector::Request.new(:my_yaml, :save, "testing", subject))

      expect(terminus.find(Puppet::Indirector::Request.new(:my_yaml, :find, "testing", nil)).name).to eq(:me)
    end

    it "should fail coherently when the stored YAML is invalid" do
      saved_structure = Struct.new(:name).new("testing")

      terminus.save(Puppet::Indirector::Request.new(:my_yaml, :save, "testing", saved_structure))
      File.open(terminus.path(saved_structure.name), "w") do |file|
        file.puts "{ invalid"
      end

      expect {
        terminus.find(Puppet::Indirector::Request.new(:my_yaml, :find, "testing", nil))
      }.to raise_error(Puppet::Error, /Could not parse YAML data/)
    end
  end

  describe "when searching" do
    it "should return an array of fact instances with one instance for each file when globbing *" do
      request = stub 'request', :key => "*", :instance => subject
      @one = mock 'one'
      @two = mock 'two'
      terminus.expects(:path).with(request.key,'').returns :glob
      Dir.expects(:glob).with(:glob).returns(%w{one.yaml two.yaml})
      YAML.expects(:load_file).with("one.yaml").returns @one;
      YAML.expects(:load_file).with("two.yaml").returns @two;
      expect(terminus.search(request)).to eq([@one, @two])
    end

    it "should return an array containing a single instance of fact when globbing 'one*'" do
      request = stub 'request', :key => "one*", :instance => subject
      @one = mock 'one'
      terminus.expects(:path).with(request.key,'').returns :glob
      Dir.expects(:glob).with(:glob).returns(%w{one.yaml})
      YAML.expects(:load_file).with("one.yaml").returns @one;
      expect(terminus.search(request)).to eq([@one])
    end

    it "should return an empty array when the glob doesn't match anything" do
      request = stub 'request', :key => "f*ilglobcanfail*", :instance => subject
      terminus.expects(:path).with(request.key,'').returns :glob
      Dir.expects(:glob).with(:glob).returns []
      expect(terminus.search(request)).to eq([])
    end

    describe "when destroying" do
      let(:path) do
        File.join(dir, terminus.class.indirection_name.to_s, request.key.to_s + ".yaml")
      end

      it "should unlink the right yaml file if it exists" do
        Puppet::FileSystem.expects(:exist?).with(path).returns true
        Puppet::FileSystem.expects(:unlink).with(path)

        terminus.destroy(request)
      end

      it "should not unlink the yaml file if it does not exists" do
        Puppet::FileSystem.expects(:exist?).with(path).returns false
        Puppet::FileSystem.expects(:unlink).with(path).never

        terminus.destroy(request)
      end
    end
  end
end
