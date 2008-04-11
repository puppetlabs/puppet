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
        else
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

    it "should have a method for converting to a ral resource" do
        trans = mock 'trans', :to_type => "yay"
        @resource = mkresource
        @resource.expects(:to_trans).returns trans
        @resource.to_type.should == "yay"
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

        it "should stack relationship metaparams from its container if it already has them" do
            @resource.set_parameter("require", "resource")
            @scope.setvar("require", "container")

            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["require"].sort.should == %w{container resource}
        end

        it "should flatten the array resulting from stacking relationship metaparams" do
            @resource.set_parameter("require", ["resource1", "resource2"])
            @scope.setvar("require", %w{container1 container2})

            @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

            @resource["require"].sort.should == %w{container1 container2 resource1 resource2}
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


    end
end
