#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/yaml'

describe Puppet::Indirector::Yaml, " when choosing file location" do
    before :each do
        @indirection = stub 'indirection', :name => :my_yaml, :register_terminus_type => nil
        Puppet::Indirector::Indirection.stubs(:instance).with(:my_yaml).returns(@indirection)
        @store_class = Class.new(Puppet::Indirector::Yaml) do
            def self.to_s
                "MyYaml::MyType"
            end
        end
        @store = @store_class.new

        @subject = Object.new
        @subject.metaclass.send(:attr_accessor, :name)
        @subject.name = :me

        @dir = "/what/ever"
        Puppet.settings.stubs(:value).returns("fakesettingdata")
        Puppet.settings.stubs(:value).with(:clientyamldir).returns(@dir)

        @request = stub 'request', :key => :me, :instance => @subject
    end

    describe Puppet::Indirector::Yaml, " when choosing file location" do
        it "should use the server_datadir if the process name is 'puppetmasterd'" do
            Puppet.settings.expects(:value).with(:name).returns "puppetmasterd"
            Puppet.settings.expects(:value).with(:yamldir).returns "/server/yaml/dir"
            @store.path(:me).should =~ %r{^/server/yaml/dir}
        end

        it "should use the client yamldir if the process name is not 'puppetmasterd'" do
            Puppet.settings.expects(:value).with(:name).returns "cient"
            Puppet.settings.expects(:value).with(:clientyamldir).returns "/client/yaml/dir"
            @store.path(:me).should =~ %r{^/client/yaml/dir}
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
        @store.expects(:base).returns "/my/yaml/dir"
        Dir.expects(:glob).with(File.join("/my/yaml/dir", @store.class.indirection_name.to_s, @request.key)).returns(%w{one.yaml two.yaml})
        YAML.expects(:load_file).with("one.yaml").returns @one;
        YAML.expects(:load_file).with("two.yaml").returns @two;
        @store.search(@request).should == [@one, @two]
      end

      it "should return an array containing a single instance of fact when globbing 'one*'" do
        @request = stub 'request', :key => "one*", :instance => @subject
        @one = mock 'one'
        @store.expects(:base).returns "/my/yaml/dir"
        Dir.expects(:glob).with(File.join("/my/yaml/dir", @store.class.indirection_name.to_s, @request.key)).returns(%w{one.yaml})
        YAML.expects(:load_file).with("one.yaml").returns @one;
        @store.search(@request).should == [@one]
      end

      it "should return an empty array when the glob doesn't match anything" do
        @request = stub 'request', :key => "f*ilglobcanfail*", :instance => @subject
        @store.expects(:base).returns "/my/yaml/dir"
        Dir.expects(:glob).with(File.join("/my/yaml/dir", @store.class.indirection_name.to_s, @request.key)).returns([])
        @store.search(@request).should == []
      end
    end
end
