#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

# LAK: FIXME This is just new tests for resources; I have
# not moved all tests over yet.

describe Puppet::Parser::Resource do
    before do
        @parser = Puppet::Parser::Parser.new :Code => ""
        @source = @parser.newclass ""
        @node = Puppet::Node.new("yaynode")
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)
        @scope = @compiler.topscope
    end

    def mkresource(args = {})
        args[:source] ||= "source"
        args[:scope] ||= stub('scope', :source => mock('source'))

        {:type => "resource", :title => "testing", :source => "source", :scope => "scope"}.each do |param, value|
            args[param] ||= value
        end

        params = args[:params] || {:one => "yay", :three => "rah"}
        if args[:params] == :none
            args.delete(:params)
        elsif not args[:params].is_a? Array
            args[:params] = paramify(args[:source], params)
        end

        Puppet::Parser::Resource.new(args)
    end

    def param(name, value, source)
        Puppet::Parser::Resource::Param.new(:name => name, :value => value, :source => source)
    end

    def paramify(source, hash)
        hash.collect do |name, value|
            Puppet::Parser::Resource::Param.new(
                :name => name, :value => value, :source => source
            )
        end
    end

    it "should use the file lookup module" do
        Puppet::Parser::Resource.ancestors.should be_include(Puppet::FileCollection::Lookup)
    end

    it "should be isomorphic if it is builtin and models an isomorphic type" do
        Puppet::Type.type(:file).expects(:isomorphic?).returns(true)
        @resource = Puppet::Parser::Resource.new(:type => "file", :title => "whatever", :scope => @scope, :source => @source).isomorphic?.should be_true
    end

    it "should not be isomorphic if it is builtin and models a non-isomorphic type" do
        Puppet::Type.type(:file).expects(:isomorphic?).returns(false)
        @resource = Puppet::Parser::Resource.new(:type => "file", :title => "whatever", :scope => @scope, :source => @source).isomorphic?.should be_false
    end

    it "should be isomorphic if it is not builtin" do
        @parser.newdefine "whatever"
        @resource = Puppet::Parser::Resource.new(:type => "whatever", :title => "whatever", :scope => @scope, :source => @source).isomorphic?.should be_true
    end

    it "should have a array-indexing method for retrieving parameter values" do
        @resource = mkresource
        @resource[:one].should == "yay"
    end

    it "should use a Puppet::Resource for converting to a ral resource" do
        trans = mock 'resource', :to_ral => "yay"
        @resource = mkresource
        @resource.expects(:to_resource).returns trans
        @resource.to_ral.should == "yay"
    end

    describe "when initializing" do
        before do
            @arguments = {:type => "resource", :title => "testing", :scope => stub('scope', :source => mock('source'))}
        end

        [:type, :title, :scope].each do |name|
            it "should fail unless #{name.to_s} is specified" do
                try = @arguments.dup
                try.delete(name)
                lambda { Puppet::Parser::Resource.new(try) }.should raise_error(ArgumentError)
            end
        end

        it "should set the reference correctly" do
            res = Puppet::Parser::Resource.new(@arguments)
            res.ref.should == "Resource[testing]"
        end

        it "should be tagged with user tags" do
            tags = [ "tag1", "tag2" ]
            @arguments[:params] = [ param(:tag, tags , :source) ]
            res = Puppet::Parser::Resource.new(@arguments)
            (res.tags & tags).should == tags
        end
    end

    describe "when refering to a resource with name canonicalization" do
        before do
            @arguments = {:type => "file", :title => "/path/", :scope => stub('scope', :source => mock('source'))}
        end

        it "should canonicalize its own name" do
            res = Puppet::Parser::Resource.new(@arguments)
            res.ref.should == "File[/path]"
        end
    end

    describe "when evaluating" do
        before do
            @type = Puppet::Parser::Resource

            @definition = @parser.newdefine "mydefine"
            @class = @parser.newclass "myclass"
            @nodedef = @parser.newnode("mynode")[0]
        end

        it "should evaluate the associated AST definition" do
            res = @type.new(:type => "mydefine", :title => "whatever", :scope => @scope, :source => @source)
            @definition.expects(:evaluate_code).with(res)

            res.evaluate
        end

        it "should evaluate the associated AST class" do
            res = @type.new(:type => "class", :title => "myclass", :scope => @scope, :source => @source)
            @class.expects(:evaluate_code).with(res)
            res.evaluate
        end

        it "should evaluate the associated AST node" do
            res = @type.new(:type => "node", :title => "mynode", :scope => @scope, :source => @source)
            @nodedef.expects(:evaluate_code).with(res)
            res.evaluate
        end
    end

    describe "when finishing" do
        before do
            @class = @parser.newclass "myclass"
            @nodedef = @parser.newnode("mynode")[0]

            @resource = Puppet::Parser::Resource.new(:type => "file", :title => "whatever", :scope => @scope, :source => @source)
        end

        it "should do nothing if it has already been finished" do
            @resource.finish
            @resource.expects(:add_metaparams).never
            @resource.finish
        end

        it "should add all defaults available from the scope" do
            @resource.scope.expects(:lookupdefaults).with(@resource.type).returns(:owner => param(:owner, "default", @resource.source))
            @resource.finish

            @resource[:owner].should == "default"
        end

        it "should not replace existing parameters with defaults" do
            @resource.set_parameter :owner, "oldvalue"
            @resource.scope.expects(:lookupdefaults).with(@resource.type).returns(:owner => :replaced)
            @resource.finish

            @resource[:owner].should == "oldvalue"
        end

        it "should add a copy of each default, rather than the actual default parameter instance" do
            newparam = param(:owner, "default", @resource.source)
            other = newparam.dup
            other.value = "other"
            newparam.expects(:dup).returns(other)
            @resource.scope.expects(:lookupdefaults).with(@resource.type).returns(:owner => newparam)
            @resource.finish

            @resource[:owner].should == "other"
        end

        it "should be running in metaparam compatibility mode if running a version below 0.25" do
            catalog = stub 'catalog', :client_version => "0.24.8"
            @resource.stubs(:catalog).returns catalog
            @resource.should be_metaparam_compatibility_mode
        end

        it "should be running in metaparam compatibility mode if running no client version is available" do
            catalog = stub 'catalog', :client_version => nil
            @resource.stubs(:catalog).returns catalog
            @resource.should be_metaparam_compatibility_mode
        end

        it "should not be running in metaparam compatibility mode if running a version at or above 0.25" do
            catalog = stub 'catalog', :client_version => "0.25.0"
            @resource.stubs(:catalog).returns catalog
            @resource.should_not be_metaparam_compatibility_mode
        end

        it "should copy metaparams from its scope" do
            @scope.setvar("noop", "true")

            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["noop"].should == "true"
        end

        it "should not copy metaparams that it already has" do
            @resource.set_parameter("noop", "false")
            @scope.setvar("noop", "true")

            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["noop"].should == "false"
        end

        it "should not copy relationship metaparams when not in metaparam compatibility mode" do
            @scope.setvar("require", "bar")

            @resource.stubs(:metaparam_compatibility_mode?).returns false
            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["require"].should be_nil
        end

        it "should copy relationship metaparams when in metaparam compatibility mode" do
            @scope.setvar("require", "bar")

            @resource.stubs(:metaparam_compatibility_mode?).returns true
            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["require"].should == "bar"
        end

        it "should stack relationship metaparams when in metaparam compatibility mode" do
            @resource.set_parameter("require", "foo")
            @scope.setvar("require", "bar")

            @resource.stubs(:metaparam_compatibility_mode?).returns true
            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["require"].should == ["foo", "bar"]
        end

        it "should copy all metaparams that it finds" do
            @scope.setvar("noop", "foo")
            @scope.setvar("schedule", "bar")

            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["noop"].should == "foo"
            @resource["schedule"].should == "bar"
        end

        it "should add any tags from the scope resource" do
            scope_resource = stub 'scope_resource', :tags => %w{one two}
            @scope.stubs(:resource).returns(scope_resource)

            @resource.class.publicize_methods(:add_scope_tags)  { @resource.add_scope_tags }

            @resource.tags.should be_include("one")
            @resource.tags.should be_include("two")
        end
    end

    describe "when being tagged" do
        before do
            @scope_resource = stub 'scope_resource', :tags => %w{srone srtwo}
            @scope = stub 'scope', :resource => @scope_resource
            @resource = Puppet::Parser::Resource.new(:type => "file", :title => "yay", :scope => @scope, :source => mock('source'))
        end

        it "should get tagged with the resource type" do
            @resource.tags.should be_include("file")
        end

        it "should get tagged with the title" do
            @resource.tags.should be_include("yay")
        end

        it "should get tagged with each name in the title if the title is a qualified class name" do
            resource = Puppet::Parser::Resource.new(:type => "file", :title => "one::two", :scope => @scope, :source => mock('source'))
            resource.tags.should be_include("one")
            resource.tags.should be_include("two")
        end

        it "should get tagged with each name in the type if the type is a qualified class name" do
            resource = Puppet::Parser::Resource.new(:type => "one::two", :title => "whatever", :scope => @scope, :source => mock('source'))
            resource.tags.should be_include("one")
            resource.tags.should be_include("two")
        end

        it "should not get tagged with non-alphanumeric titles" do
            resource = Puppet::Parser::Resource.new(:type => "file", :title => "this is a test", :scope => @scope, :source => mock('source'))
            resource.tags.should_not be_include("this is a test")
        end

        it "should fail on tags containing '*' characters" do
            lambda { @resource.tag("bad*tag") }.should raise_error(Puppet::ParseError)
        end

        it "should fail on tags starting with '-' characters" do
            lambda { @resource.tag("-badtag") }.should raise_error(Puppet::ParseError)
        end

        it "should fail on tags containing ' ' characters" do
            lambda { @resource.tag("bad tag") }.should raise_error(Puppet::ParseError)
        end

        it "should allow alpha tags" do
            lambda { @resource.tag("good_tag") }.should_not raise_error(Puppet::ParseError)
        end
    end

    describe "when merging overrides" do
        before do
            @source = "source1"
            @resource = mkresource :source => @source
            @override = mkresource :source => @source
        end

        it "should fail when the override was not created by a parent class" do
            @override.source = "source2"
            @override.source.expects(:child_of?).with("source1").returns(false)
            lambda { @resource.merge(@override) }.should raise_error(Puppet::ParseError)
        end

        it "should succeed when the override was created in the current scope" do
            @resource.source = "source3"
            @override.source = @resource.source
            @override.source.expects(:child_of?).with("source3").never
            params = {:a => :b, :c => :d}
            @override.expects(:params).returns(params)
            @resource.expects(:override_parameter).with(:b)
            @resource.expects(:override_parameter).with(:d)
            @resource.merge(@override)
        end

        it "should succeed when a parent class created the override" do
            @resource.source = "source3"
            @override.source = "source4"
            @override.source.expects(:child_of?).with("source3").returns(true)
            params = {:a => :b, :c => :d}
            @override.expects(:params).returns(params)
            @resource.expects(:override_parameter).with(:b)
            @resource.expects(:override_parameter).with(:d)
            @resource.merge(@override)
        end

        it "should add new parameters when the parameter is not set" do
            @source.stubs(:child_of?).returns true
            @override.set_parameter(:testing, "value")
            @resource.merge(@override)

            @resource[:testing].should == "value"
        end

        it "should replace existing parameter values" do
            @source.stubs(:child_of?).returns true
            @resource.set_parameter(:testing, "old")
            @override.set_parameter(:testing, "value")

            @resource.merge(@override)

            @resource[:testing].should == "value"
        end

        it "should add values to the parameter when the override was created with the '+>' syntax" do
            @source.stubs(:child_of?).returns true
            param = Puppet::Parser::Resource::Param.new(:name => :testing, :value => "testing", :source => @resource.source)
            param.add = true

            @override.set_parameter(param)

            @resource.set_parameter(:testing, "other")

            @resource.merge(@override)

            @resource[:testing].should == %w{other testing}
        end

        it "should promote tag overrides to real tags" do
            @source.stubs(:child_of?).returns true
            param = Puppet::Parser::Resource::Param.new(:name => :tag, :value => "testing", :source => @resource.source)

            @override.set_parameter(param)

            @resource.merge(@override)

            @resource.tagged?("testing").should be_true
        end

    end

    it "should be able to be converted to a normal resource" do
        @source = stub 'scope', :name => "myscope"
        @resource = mkresource :source => @source
        @resource.should respond_to(:to_resource)
    end

    it "should use its resource converter to convert to a transportable resource" do
        @source = stub 'scope', :name => "myscope"
        @resource = mkresource :source => @source

        newresource = Puppet::Resource.new(:file, "/my")
        Puppet::Resource.expects(:new).returns(newresource)

        newresource.expects(:to_trans).returns "mytrans"

        @resource.to_trans.should == "mytrans"
    end

    it "should return nil if converted to a transportable resource and it is virtual" do
        @source = stub 'scope', :name => "myscope"
        @resource = mkresource :source => @source

        @resource.expects(:virtual?).returns true
        @resource.to_trans.should be_nil
    end

    describe "when being converted to a resource" do
        before do
            @source = stub 'scope', :name => "myscope"
            @parser_resource = mkresource :source => @source, :params => {:foo => "bar", :fee => "fum"}
        end

        it "should create an instance of Puppet::Resource" do
            @parser_resource.to_resource.should be_instance_of(Puppet::Resource)
        end

        it "should set the type correctly on the Puppet::Resource" do
            @parser_resource.to_resource.type.should == @parser_resource.type
        end

        it "should set the title correctly on the Puppet::Resource" do
            @parser_resource.to_resource.title.should == @parser_resource.title
        end

        it "should copy over all of the parameters" do
            result = @parser_resource.to_resource.to_hash

            # The name will be in here, also.
            result[:foo].should == "bar"
            result[:fee].should == "fum"
        end

        it "should copy over the tags" do
            @parser_resource.tag "foo"
            @parser_resource.tag "bar"

            @parser_resource.to_resource.tags.should == @parser_resource.tags
        end

        it "should copy over the line" do
            @parser_resource.line = 40
            @parser_resource.to_resource.line.should == 40
        end

        it "should copy over the file" do
            @parser_resource.file = "/my/file"
            @parser_resource.to_resource.file.should == "/my/file"
        end

        it "should copy over the 'exported' value" do
            @parser_resource.exported = true
            @parser_resource.to_resource.exported.should be_true
        end

        it "should copy over the 'virtual' value" do
            @parser_resource.virtual = true
            @parser_resource.to_resource.virtual.should be_true
        end

        it "should convert any parser resource references to Puppet::Resource::Reference instances" do
            ref = Puppet::Parser::Resource::Reference.new(:title => "/my/file", :type => "file")
            @parser_resource = mkresource :source => @source, :params => {:foo => "bar", :fee => ref}
            result = @parser_resource.to_resource
            result[:fee].should == Puppet::Resource::Reference.new(:file, "/my/file")
        end

        it "should convert any parser resource references to Puppet::Resource::Reference instances even if they are in an array" do
            ref = Puppet::Parser::Resource::Reference.new(:title => "/my/file", :type => "file")
            @parser_resource = mkresource :source => @source, :params => {:foo => "bar", :fee => ["a", ref]}
            result = @parser_resource.to_resource
            result[:fee].should == ["a", Puppet::Resource::Reference.new(:file, "/my/file")]
        end

        it "should convert any parser resource references to Puppet::Resource::Reference instances even if they are in an array of array, and even deeper" do
            ref1 = Puppet::Parser::Resource::Reference.new(:title => "/my/file1", :type => "file")
            ref2 = Puppet::Parser::Resource::Reference.new(:title => "/my/file2", :type => "file")
            @parser_resource = mkresource :source => @source, :params => {:foo => "bar", :fee => ["a", [ref1,ref2]]}
            result = @parser_resource.to_resource
            result[:fee].should == ["a", Puppet::Resource::Reference.new(:file, "/my/file1"), Puppet::Resource::Reference.new(:file, "/my/file2")]
        end

        it "should fail if the same param is declared twice" do
            lambda do 
                @parser_resource = mkresource :source => @source, :params => [
                    Puppet::Parser::Resource::Param.new(
                        :name => :foo, :value => "bar", :source => @source
                    ),
                    Puppet::Parser::Resource::Param.new(
                        :name => :foo, :value => "baz", :source => @source
                    )
                ]
            end.should raise_error(Puppet::ParseError)
        end
    end
end
