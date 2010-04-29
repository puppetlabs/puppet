#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

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
            @loader.load_until(["foo"], "") { |f| false }.should be_nil
        end

        it "should turn the provided namespaces and name into a list of files" do
            @loader.expects(:name2files).with(["foo"], "bar").returns []
            @loader.load_until(["foo"], "bar") { |f| false }
        end

        it "should attempt to import each generated name" do
            @loader.expects(:name2files).returns %w{foo bar}
            @loader.expects(:import).with("foo")
            @loader.expects(:import).with("bar")
            @loader.load_until(["foo"], "bar") { |f| false }
        end

        it "should yield after each import" do
            yielded = []
            @loader.expects(:name2files).returns %w{foo bar}
            @loader.expects(:import).with("foo")
            @loader.expects(:import).with("bar")
            @loader.load_until(["foo"], "bar") { |f| yielded << f; false }
            yielded.should == %w{foo bar}
        end

        it "should stop importing when the yielded block returns true" do
            yielded = []
            @loader.expects(:name2files).returns %w{foo bar baz}
            @loader.expects(:import).with("foo")
            @loader.expects(:import).with("bar")
            @loader.expects(:import).with("baz").never
            @loader.load_until(["foo"], "bar") { |f| true if f == "bar" }
        end

        it "should return the result of the block" do
            yielded = []
            @loader.expects(:name2files).returns %w{foo bar baz}
            @loader.expects(:import).with("foo")
            @loader.expects(:import).with("bar")
            @loader.expects(:import).with("baz").never
            @loader.load_until(["foo"], "bar") { |f| 10 if f == "bar" }.should == 10
        end

        it "should return nil if the block never returns true" do
            @loader.expects(:name2files).returns %w{foo bar}
            @loader.expects(:import).with("foo")
            @loader.expects(:import).with("bar")
            @loader.load_until(["foo"], "bar") { |f| false }.should be_nil
        end

        it "should know when a given name has been loaded" do
            @loader.expects(:name2files).returns %w{file}
            @loader.expects(:import).with("file")
            @loader.load_until(["foo"], "bar") { |f| true }
            @loader.should be_loaded("file")
        end
    end

    describe "when mapping names to files" do
        {
            [["foo"], "::bar::baz"] => %w{bar/baz},
            [[""], "foo::bar"]      => %w{foo foo/bar},
            [%w{foo}, "bar"]        => %w{foo foo/bar bar},
            [%w{a b}, "bar"]        => %w{a a/bar b b/bar bar},
            [%w{a::b::c}, "bar"]    => %w{a a/b/c/bar bar},
            [%w{a::b}, "foo::bar"]  => %w{a a/b/foo/bar foo/bar}
        }.each do |inputs, outputs|
            it "should produce #{outputs.inspect} from the #{inputs[0].inspect} namespace and #{inputs[1]} name" do
                @loader.name2files(*inputs).should == outputs
            end
        end
    end

    describe "when importing" do
        before do
            Puppet::Parser::Files.stubs(:find_manifests).returns %w{file}
            @loader.stubs(:parse_file)
        end

        it "should return immediately when imports are being ignored" do
            Puppet::Parser::Files.expects(:find_manifests).never
            Puppet[:ignoreimport] = true
            @loader.import("foo").should be_nil
        end

        it "should find all manifests matching the file or pattern" do
            Puppet::Parser::Files.expects(:find_manifests).with { |pat, opts| pat == "myfile" }.returns %w{one}
            @loader.import("myfile")
        end

        it "should use the directory of the current file if one is set" do
            Puppet::Parser::Files.expects(:find_manifests).with { |pat, opts| opts[:cwd] == "/current" }.returns %w{one}
            @loader.import("myfile", "/current/file")
        end

        it "should pass the environment when looking for files" do
            Puppet::Parser::Files.expects(:find_manifests).with { |pat, opts| opts[:environment] == @loader.environment }.returns %w{one}
            @loader.import("myfile")
        end

        it "should fail if no files are found" do
            Puppet::Parser::Files.expects(:find_manifests).returns []
            lambda { @loader.import("myfile") }.should raise_error(Puppet::ImportError)
        end

        it "should parse each found file" do
            Puppet::Parser::Files.expects(:find_manifests).returns %w{/one}
            @loader.expects(:parse_file).with("/one")
            @loader.import("myfile")
        end

        it "should make each file qualified before attempting to parse it" do
            Puppet::Parser::Files.expects(:find_manifests).returns %w{one}
            @loader.expects(:parse_file).with("/current/one")
            @loader.import("myfile", "/current/file")
        end

        it "should know when a given file has been imported" do
            Puppet::Parser::Files.expects(:find_manifests).returns %w{/one}
            @loader.import("myfile")

            @loader.should be_imported("/one")
        end

        it "should not attempt to import files that have already been imported" do
            Puppet::Parser::Files.expects(:find_manifests).returns %w{/one}
            @loader.expects(:parse_file).once
            @loader.import("myfile")

            # This will fail if it tries to reimport the file.
            @loader.import("myfile")
        end
    end

    describe "when parsing a file" do
        before do
            @parser = Puppet::Parser::Parser.new(@loader.environment)
            @parser.stubs(:parse)
            @parser.stubs(:file=)
            Puppet::Parser::Parser.stubs(:new).with(@loader.environment).returns @parser
        end

        it "should create a new parser instance for each file using the current environment" do
            Puppet::Parser::Parser.expects(:new).with(@loader.environment).returns @parser
            @loader.parse_file("/my/file")
        end

        it "should assign the parser its file and parse" do
            @parser.expects(:file=).with("/my/file")
            @parser.expects(:parse)
            @loader.parse_file("/my/file")
        end
    end

    it "should be able to add classes to the current resource type collection" do
        file = tmpfile("simple_file")
        File.open(file, "w") { |f| f.puts "class foo {}" }
        @loader.import(file)

        @loader.known_resource_types.hostclass("foo").should be_instance_of(Puppet::Resource::Type)
    end
end
