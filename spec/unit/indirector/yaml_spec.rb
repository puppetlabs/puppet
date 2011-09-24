#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/yaml'

describe Puppet::Indirector::Yaml, " when choosing file location" do
  before :all do
    @indirection = stub 'indirection', :name => :my_yaml, :register_terminus_type => nil
    Puppet::Indirector::Indirection.expects(:instance).with(:my_yaml).returns(@indirection)
    module MyYaml; end
    @store_class = class MyYaml::MyType < Puppet::Indirector::Yaml
      self
    end
  end
  before :each do
    @store = @store_class.new

    @subject = Object.new
    @subject.singleton_class.send(:attr_accessor, :name)
    @subject.name = :me

    @dir = "/what/ever"
    Puppet.settings.stubs(:value).returns("fakesettingdata")
    Puppet.settings.stubs(:value).with(:clientyamldir).returns(@dir)
    Puppet.run_mode.stubs(:master?).returns false

    @request = stub 'request', :key => :me, :instance => @subject
  end

  describe Puppet::Indirector::Yaml, " when choosing file location" do
    it "should use the server_datadir if the run_mode is master" do
      Puppet.run_mode.expects(:master?).returns true
      Puppet.settings.expects(:value).with(:yamldir).returns "/server/yaml/dir"
      @store.path(:me).should =~ %r{^/server/yaml/dir}
    end

    it "should use the client yamldir if the run_mode is not master" do
      Puppet.run_mode.expects(:master?).returns false
      Puppet.settings.expects(:value).with(:clientyamldir).returns "/client/yaml/dir"
      @store.path(:me).should =~ %r{^/client/yaml/dir}
    end

    it "should use the extension if one is specified" do
      Puppet.run_mode.expects(:master?).returns true
      Puppet.settings.expects(:value).with(:yamldir).returns "/server/yaml/dir"
      @store.path(:me,'.farfignewton').should =~ %r{\.farfignewton$}
    end

    it "should assume an extension of .yaml if none is specified" do
      Puppet.run_mode.expects(:master?).returns true
      Puppet.settings.expects(:value).with(:yamldir).returns "/server/yaml/dir"
      @store.path(:me).should =~ %r{\.yaml$}
    end

    it "should store all files in a single file root set in the Puppet defaults" do
      @store.path(:me).should =~ %r{^#{@dir}}
    end

    it "should use the terminus name for choosing the subdirectory" do
      @store.path(:me).should =~ %r{^#{@dir}/my_yaml}
    end

    it "should use the object's name to determine the file name" do
      @store.path(:me).should =~ %r{me.yaml$}
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
        expect { @store.path(input) }.to raise_error
      end
    end
  end

  describe Puppet::Indirector::Yaml, " when storing objects as YAML" do
    it "should only store objects that respond to :name" do
      @request.stubs(:instance).returns Object.new
      proc { @store.save(@request) }.should raise_error(ArgumentError)
    end

    it "should convert Ruby objects to YAML and write them to disk using a write lock" do
      yaml = @subject.to_yaml
      file = mock 'file'
      path = @store.send(:path, @subject.name)
      FileTest.expects(:exist?).with(File.dirname(path)).returns(true)
      @store.expects(:writelock).with(path, 0660).yields(file)
      file.expects(:print).with(yaml)

      @store.save(@request)
    end

    it "should create the indirection subdirectory if it does not exist" do
      yaml = @subject.to_yaml
      file = mock 'file'
      path = @store.send(:path, @subject.name)
      dir = File.dirname(path)

      FileTest.expects(:exist?).with(dir).returns(false)
      Dir.expects(:mkdir).with(dir)

      @store.expects(:writelock).yields(file)
      file.expects(:print).with(yaml)

      @store.save(@request)
    end
  end

  describe Puppet::Indirector::Yaml, " when retrieving YAML" do
    it "should read YAML in from disk using a read lock and convert it to Ruby objects" do
      path = @store.send(:path, @subject.name)

      yaml = @subject.to_yaml
      FileTest.expects(:exist?).with(path).returns(true)

      fh = mock 'filehandle'
      @store.expects(:readlock).with(path).yields fh
      fh.expects(:read).returns yaml

      @store.find(@request).instance_variable_get("@name").should == :me
    end

    it "should fail coherently when the stored YAML is invalid" do
      path = @store.send(:path, @subject.name)
      FileTest.expects(:exist?).with(path).returns(true)

      # Something that will fail in yaml
      yaml = "--- !ruby/object:Hash"

      fh = mock 'filehandle'
      @store.expects(:readlock).yields fh
      fh.expects(:read).returns yaml

      proc { @store.find(@request) }.should raise_error(Puppet::Error)
    end
  end

  describe Puppet::Indirector::Yaml, " when searching" do
    it "should return an array of fact instances with one instance for each file when globbing *" do
      @request = stub 'request', :key => "*", :instance => @subject
      @one = mock 'one'
      @two = mock 'two'
      @store.expects(:path).with(@request.key,'').returns :glob
      Dir.expects(:glob).with(:glob).returns(%w{one.yaml two.yaml})
      YAML.expects(:load_file).with("one.yaml").returns @one;
      YAML.expects(:load_file).with("two.yaml").returns @two;
      @store.search(@request).should == [@one, @two]
    end

    it "should return an array containing a single instance of fact when globbing 'one*'" do
      @request = stub 'request', :key => "one*", :instance => @subject
      @one = mock 'one'
      @store.expects(:path).with(@request.key,'').returns :glob
      Dir.expects(:glob).with(:glob).returns(%w{one.yaml})
      YAML.expects(:load_file).with("one.yaml").returns @one;
      @store.search(@request).should == [@one]
    end

    it "should return an empty array when the glob doesn't match anything" do
      @request = stub 'request', :key => "f*ilglobcanfail*", :instance => @subject
      @store.expects(:path).with(@request.key,'').returns :glob
      Dir.expects(:glob).with(:glob).returns []
      @store.search(@request).should == []
    end

    describe Puppet::Indirector::Yaml, " when destroying" do
      it "should unlink the right yaml file if it exists" do
        path = File.join("/what/ever", @store.class.indirection_name.to_s, @request.key.to_s + ".yaml")
        File.expects(:exists?).with(path).returns true
        File.expects(:unlink).with(path)

        @store.destroy(@request)
      end

      it "should not unlink the yaml file if it does not exists" do
        path = File.join("/what/ever", @store.class.indirection_name.to_s, @request.key.to_s + ".yaml")
        File.expects(:exists?).with(path).returns false
        File.expects(:unlink).with(path).never

        @store.destroy(@request)
      end
    end
  end
end
