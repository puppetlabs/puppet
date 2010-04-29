#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/resource/type_collection'
require 'puppet/resource/type'

describe Puppet::Resource::TypeCollection do
    before do
        @instance = Puppet::Resource::Type.new(:hostclass, "foo")
        @code = Puppet::Resource::TypeCollection.new("env")
    end

    it "should require an environment at initialization" do
        env = Puppet::Node::Environment.new("testing")
        Puppet::Resource::TypeCollection.new(env).environment.should equal(env)
    end

    it "should convert the environment into an environment instance if a string is provided" do
        env = Puppet::Node::Environment.new("testing")
        Puppet::Resource::TypeCollection.new("testing").environment.should equal(env)
    end

    it "should create a 'loader' at initialization" do
        Puppet::Resource::TypeCollection.new("testing").loader.should be_instance_of(Puppet::Parser::TypeLoader)
    end

    it "should be able to add a resource type" do
        Puppet::Resource::TypeCollection.new("env").should respond_to(:add)
    end

    it "should consider '<<' to be an alias to 'add' but should return self" do
        loader = Puppet::Resource::TypeCollection.new("env")
        loader.expects(:add).with "foo"
        loader.expects(:add).with "bar"
        loader << "foo" << "bar"
    end

    it "should set itself as the code collection for added resource types" do
        loader = Puppet::Resource::TypeCollection.new("env")

        node = Puppet::Resource::Type.new(:node, "foo")

        @code.add(node)
        @code.node("foo").should equal(node)

        node.resource_type_collection.should equal(@code)
    end

    it "should store node resource types as nodes" do
        node = Puppet::Resource::Type.new(:node, "foo")

        @code.add(node)
        @code.node("foo").should equal(node)
    end

    it "should store hostclasses as hostclasses" do
        klass = Puppet::Resource::Type.new(:hostclass, "foo")

        @code.add(klass)
        @code.hostclass("foo").should equal(klass)
    end

    it "should store definitions as definitions" do
        define = Puppet::Resource::Type.new(:definition, "foo")

        @code.add(define)
        @code.definition("foo").should equal(define)
    end

    it "should merge new classes with existing classes of the same name" do
        loader = Puppet::Resource::TypeCollection.new("env")
        first = Puppet::Resource::Type.new(:hostclass, "foo")
        second = Puppet::Resource::Type.new(:hostclass, "foo")
        loader.add first
        first.expects(:merge).with(second)
        loader.add(second)
    end

    it "should remove all nodes, classes, and definitions when cleared" do
        loader = Puppet::Resource::TypeCollection.new("env")
        loader.add Puppet::Resource::Type.new(:hostclass, "class")
        loader.add Puppet::Resource::Type.new(:definition, "define")
        loader.add Puppet::Resource::Type.new(:node, "node")

        loader.clear
        loader.hostclass("class").should be_nil
        loader.definition("define").should be_nil
        loader.node("node").should be_nil
    end

    describe "when looking up names" do
        before do
            @type = Puppet::Resource::Type.new(:hostclass, "ns::klass")
        end

        it "should support looking up with multiple namespaces" do
            @code.add @type
            @code.find_hostclass(%w{boo baz ns}, "klass").should equal(@type)
        end

        it "should not attempt to import anything when the type is already defined" do
            @code.add @type
            @code.loader.expects(:import).never
            @code.find_hostclass(%w{ns}, "klass").should equal(@type)
        end

        describe "that need to be loaded" do
            it "should use the loader to load the files" do
                @code.loader.expects(:load_until).with(["ns"], "klass")
                @code.find_or_load(["ns"], "klass", :hostclass)
            end

            it "should downcase the name and downcase and array-fy the namespaces before passing to the loader" do
                @code.loader.expects(:load_until).with(["ns"], "klass")
                @code.find_or_load("Ns", "Klass", :hostclass)
            end

            it "should attempt to find the type when the loader yields" do
                @code.loader.expects(:load_until).yields
                @code.expects(:find).with(["ns"], "klass", :hostclass).times(2).returns(false).then.returns(true)
                @code.find_or_load("ns", "klass", :hostclass)
            end

            it "should return the result of 'load_until'" do
                @code.loader.expects(:load_until).returns "foo"
                @code.find_or_load("Ns", "Klass", :hostclass).should == "foo"
            end

            it "should return nil if the name isn't found" do
                @code.stubs(:load_until).returns(nil)
                @code.find_or_load("Ns", "Klass", :hostclass).should be_nil
            end
        end
    end

    %w{hostclass node definition}.each do |data|
        before do
            @instance = Puppet::Resource::Type.new(data, "foo")
        end

        it "should have a method for adding a #{data}" do
            Puppet::Resource::TypeCollection.new("env").should respond_to("add_" + data)
        end

        it "should use the name of the instance to add it" do
            loader = Puppet::Resource::TypeCollection.new("env")
            loader.send("add_#{data}", @instance)
            loader.send(data, @instance.name).should equal(@instance)
        end

        unless data == "hostclass"
            it "should fail to add a #{data} when one already exists" do
                loader = Puppet::Resource::TypeCollection.new("env")
                loader.add @instance
                lambda { loader.add(@instance) }.should raise_error(Puppet::ParseError)
            end
        end

        it "should return the added #{data}" do
            loader = Puppet::Resource::TypeCollection.new("env")

            loader.add(@instance).should equal(@instance)
        end

        it "should be able to retrieve #{data} by name" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(data, "bar")
            loader.add instance
            loader.send(data, "bar").should equal(instance)
        end

        it "should retrieve #{data} insensitive to case" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(data, "Bar")
            loader.add instance
            loader.send(data, "bAr").should equal(instance)
        end

        it "should return nil when asked for a #{data} that has not been added" do
            Puppet::Resource::TypeCollection.new("env").send(data, "foo").should be_nil
        end

        it "should be able to retrieve all #{data}s" do
            plurals = { "hostclass" => "hostclasses", "node" => "nodes", "definition" => "definitions" }
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(data, "foo")
            loader.add instance
            loader.send(plurals[data]).should == { "foo" => instance }
        end
    end

    describe "when finding a qualified instance" do
        it "should return any found instance if the instance name is fully qualified" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar")
            loader.add instance
            loader.find("namespace", "::foo::bar", :hostclass).should equal(instance)
        end

        it "should return nil if the instance name is fully qualified and no such instance exists" do
            loader = Puppet::Resource::TypeCollection.new("env")
            loader.find("namespace", "::foo::bar", :hostclass).should be_nil
        end

        it "should be able to find classes in the base namespace" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo")
            loader.add instance
            loader.find("", "foo", :hostclass).should equal(instance)
        end

        it "should return the partially qualified object if it exists in a provided namespace" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo", "bar::baz", :hostclass).should equal(instance)
        end

        it "should be able to find partially qualified objects in any of the provided namespaces" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find(["nons", "foo", "otherns"], "bar::baz", :hostclass).should equal(instance)
        end

        it "should return the unqualified object if it exists in a provided namespace" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar")
            loader.add instance
            loader.find("foo", "bar", :hostclass).should equal(instance)
        end

        it "should return the unqualified object if it exists in the parent namespace" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar")
            loader.add instance
            loader.find("foo::bar::baz", "bar", :hostclass).should equal(instance)
        end

        it "should should return the partially qualified object if it exists in the parent namespace" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo::bar", "bar::baz", :hostclass).should equal(instance)
        end

        it "should return the qualified object if it exists in the root namespace" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo::bar", "foo::bar::baz", :hostclass).should equal(instance)
        end

        it "should return nil if the object cannot be found" do
            loader = Puppet::Resource::TypeCollection.new("env")
            instance = Puppet::Resource::Type.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo::bar", "eh", :hostclass).should be_nil
        end
    end

    it "should use the generic 'find' method with an empty namespace to find nodes" do
        loader = Puppet::Resource::TypeCollection.new("env")
        loader.expects(:find).with("", "bar", :node)
        loader.find_node("bar")
    end

    it "should use the 'find_or_load' method to find hostclasses" do
        loader = Puppet::Resource::TypeCollection.new("env")
        loader.expects(:find_or_load).with("foo", "bar", :hostclass)
        loader.find_hostclass("foo", "bar")
    end

    it "should use the 'find_or_load' method to find definitions" do
        loader = Puppet::Resource::TypeCollection.new("env")
        loader.expects(:find_or_load).with("foo", "bar", :definition)
        loader.find_definition("foo", "bar")
    end

    it "should indicate whether any nodes are defined" do
        loader = Puppet::Resource::TypeCollection.new("env")
        loader.add_node(Puppet::Resource::Type.new(:node, "foo"))
        loader.should be_nodes
    end

    it "should indicate whether no nodes are defined" do
        Puppet::Resource::TypeCollection.new("env").should_not be_nodes
    end

    describe "when finding nodes" do
        before :each do
            @loader = Puppet::Resource::TypeCollection.new("env")
        end

        it "should return any node whose name exactly matches the provided node name" do
            node = Puppet::Resource::Type.new(:node, "foo")
            @loader << node

            @loader.node("foo").should equal(node)
        end

        it "should return the first regex node whose regex matches the provided node name" do
            node1 = Puppet::Resource::Type.new(:node, /\w/)
            node2 = Puppet::Resource::Type.new(:node, /\d/)
            @loader << node1 << node2

            @loader.node("foo10").should equal(node1)
        end

        it "should preferentially return a node whose name is string-equal over returning a node whose regex matches a provided name" do
            node1 = Puppet::Resource::Type.new(:node, /\w/)
            node2 = Puppet::Resource::Type.new(:node, "foo")
            @loader << node1 << node2

            @loader.node("foo").should equal(node2)
        end
    end

    describe "when managing files" do
        before do
            @loader = Puppet::Resource::TypeCollection.new("env")
            Puppet::Util::LoadedFile.stubs(:new).returns stub("watched_file")
        end

        it "should have a method for specifying a file should be watched" do
            @loader.should respond_to(:watch_file)
        end

        it "should have a method for determining if a file is being watched" do
            @loader.watch_file("/foo/bar")
            @loader.should be_watching_file("/foo/bar")
        end

        it "should use LoadedFile to watch files" do
            Puppet::Util::LoadedFile.expects(:new).with("/foo/bar").returns stub("watched_file")
            @loader.watch_file("/foo/bar")
        end

        it "should be considered stale if any files have changed" do
            file1 = stub 'file1', :changed? => false
            file2 = stub 'file2', :changed? => true
            Puppet::Util::LoadedFile.expects(:new).times(2).returns(file1).then.returns(file2)
            @loader.watch_file("/foo/bar")
            @loader.watch_file("/other/bar")

            @loader.should be_stale
        end

        it "should not be considered stable if no files have changed" do
            file1 = stub 'file1', :changed? => false
            file2 = stub 'file2', :changed? => false
            Puppet::Util::LoadedFile.expects(:new).times(2).returns(file1).then.returns(file2)
            @loader.watch_file("/foo/bar")
            @loader.watch_file("/other/bar")

            @loader.should_not be_stale
        end
    end

    describe "when performing initial import" do
        before do
            @parser = stub 'parser', :file= => nil, :string => nil, :parse => nil
            Puppet::Parser::Parser.stubs(:new).returns @parser
            @code = Puppet::Resource::TypeCollection.new("env")
        end

        it "should create a new parser instance" do
            Puppet::Parser::Parser.expects(:new).returns @parser
            @code.perform_initial_import
        end

        it "should set the parser's string to the 'code' setting and parse if code is available" do
            Puppet.settings[:code] = "my code"
            @parser.expects(:string=).with "my code"
            @parser.expects(:parse)
            @code.perform_initial_import
        end

        it "should set the parser's file to the 'manifest' setting and parse if no code is available and the manifest is available" do
            File.expects(:exist?).with("/my/file").returns true
            Puppet.settings[:manifest] = "/my/file"
            @parser.expects(:file=).with "/my/file"
            @parser.expects(:parse)
            @code.perform_initial_import
        end

        it "should not attempt to load a manifest if none is present" do
            File.expects(:exist?).with("/my/file").returns false
            Puppet.settings[:manifest] = "/my/file"
            @parser.expects(:file=).never
            @parser.expects(:parse).never
            @code.perform_initial_import
        end

        it "should fail helpfully if there is an error importing" do
            File.stubs(:exist?).returns true
            @parser.expects(:parse).raises ArgumentError
            lambda { @code.perform_initial_import }.should raise_error(Puppet::Error)
        end
    end

    describe "when determining the configuration version" do
        before do
            @code = Puppet::Resource::TypeCollection.new("env")
        end

        it "should default to the current time" do
            time = Time.now

            Time.stubs(:now).returns time
            @code.version.should == time.to_i
        end

        it "should use the output of the environment's config_version setting if one is provided" do
            @code.environment.stubs(:[]).with(:config_version).returns("/my/foo")

            Puppet::Util.expects(:execute).with(["/my/foo"]).returns "output\n"
            @code.version.should == "output"
        end

        it "should raise a puppet parser error if executing config_version fails" do
            @code.environment.stubs(:[]).with(:config_version).returns("test")
            Puppet::Util.expects(:execute).raises(Puppet::ExecutionFailure.new("msg"))

            lambda { @code.version }.should raise_error(Puppet::ParseError)
        end

    end
end
