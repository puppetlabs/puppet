#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Definition, "when initializing" do
end

describe Puppet::Parser::AST::Definition, "when evaluating" do
    before do
        @type = Puppet::Parser::Resource
        @parser = Puppet::Parser::Parser.new :Code => ""
        @source = @parser.newclass ""
        @definition = @parser.newdefine "mydefine"
        @node = Puppet::Node.new("yaynode")
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)
        @scope = @compiler.topscope

        @resource = Puppet::Parser::Resource.new(:type => "mydefine", :title => "myresource", :scope => @scope, :source => @source)
    end

    it "should create a new scope" do
        scope = nil
        code = mock 'code'
        code.expects(:safeevaluate).with do |scope|
            scope.object_id.should_not == @scope.object_id
            true
        end
        @definition.stubs(:code).returns(code)
        @definition.evaluate_code(@resource)
    end

    it "should have a get_classname method" do
        @definition.should respond_to :get_classname
    end

    it "should return the current classname with get_classname" do
        @definition.expects(:classname)

        @definition.get_classname(@scope)
    end

    describe "when evaluating" do
        it "should create a resource whose title comes from get_classname" do
            @definition.expects(:get_classname).returns("classname")

            @definition.evaluate(@scope)
        end
    end

#    it "should copy its namespace to the scope"
#
#    it "should mark the scope virtual if the resource is virtual"
#
#    it "should mark the scope exported if the resource is exported"
#
#    it "should set the resource's parameters as variables in the scope"
#
#    it "should set the resource's title as a variable in the scope"
#
#    it "should copy the resource's title in a 'name' variable in the scope"
#
#    it "should not copy the resource's title as the name if 'name' is one of the resource parameters"
#
#    it "should evaluate the associated code with the new scope"

    def old_test_initialize
        parser = mkparser

        # Create a new definition
        klass = parser.newdefine "yayness",
            :arguments => [["owner", stringobj("nobody")], %w{mode}],
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/$name",
                        "owner" => varref("owner"), "mode" => varref("mode"))]
            )

        # Test validattr? a couple different ways
        [:owner, "owner", :schedule, "schedule"].each do |var|
            assert(klass.validattr?(var), "%s was not considered valid" % var.inspect)
        end

        [:random, "random"].each do |var|
            assert(! klass.validattr?(var), "%s was considered valid" % var.inspect)
        end

    end

    def oldtest_evaluate
        parser = mkparser
        config = mkcompiler
        config.send(:evaluate_main)
        scope = config.topscope
        klass = parser.newdefine "yayness",
            :arguments => [["owner", stringobj("nobody")], %w{mode}],
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/$name",
                        "owner" => varref("owner"), "mode" => varref("mode"))]
            )

        resource = Puppet::Parser::Resource.new(
            :title => "first",
            :type => "yayness",
            :exported => false,
            :virtual => false,
            :scope => scope,
            :source => scope.source
        )
        resource.send(:set_parameter, "name", "first")
        resource.send(:set_parameter, "mode", "755")

        resource.stubs(:title)
        assert_nothing_raised do
            klass.evaluate_code(resource)
        end

        firstobj = config.findresource("File[/tmp/first]")
        assert(firstobj, "Did not create /tmp/first obj")

        assert_equal("File", firstobj.type)
        assert_equal("/tmp/first", firstobj.title)
        assert_equal("nobody", firstobj[:owner])
        assert_equal("755", firstobj[:mode])

        # Make sure we can't evaluate it with the same args
        assert_raise(Puppet::ParseError) do
            klass.evaluate_code(resource)
        end

        # Now create another with different args
        resource2 = Puppet::Parser::Resource.new(
            :title => "second",
            :type => "yayness",
            :exported => false,
            :virtual => false,
            :scope => scope,
            :source => scope.source
        )
        resource2.send(:set_parameter, "name", "second")
        resource2.send(:set_parameter, "mode", "755")
        resource2.send(:set_parameter, "owner", "daemon")

        assert_nothing_raised do
            klass.evaluate_code(resource2)
        end

        secondobj = config.findresource("File[/tmp/second]")
        assert(secondobj, "Did not create /tmp/second obj")

        assert_equal("File", secondobj.type)
        assert_equal("/tmp/second", secondobj.title)
        assert_equal("daemon", secondobj[:owner])
        assert_equal("755", secondobj[:mode])
    end

    # #539 - definitions should support both names and titles
    def oldtest_names_and_titles
        parser = mkparser
        scope = mkscope :parser => parser

        [
            {:name => "one", :title => "two"},
            {:title => "mytitle"}
        ].each_with_index do |hash, i|
            # Create a definition that uses both name and title.  Put this
            # inside the loop so the subscope expectations work.
            klass = parser.newdefine "yayness%s" % i

            resource = Puppet::Parser::Resource.new(
                :title => hash[:title],
                :type => "yayness%s" % i,
                :exported => false,
                :virtual => false,
                :scope => scope,
                :source => scope.source
            )

            subscope = klass.subscope(scope, resource)

            klass.expects(:subscope).returns(subscope)

            if hash[:name]
                resource.stubs(:to_hash).returns({:name => hash[:name]})
            end

            assert_nothing_raised("Could not evaluate definition with %s" % hash.inspect) do
                klass.evaluate_code(resource)
            end

            name = hash[:name] || hash[:title]
            title = hash[:title]

            assert_equal(name, subscope.lookupvar("name"),
                "Name did not get set correctly")
            assert_equal(title, subscope.lookupvar("title"),
                "title did not get set correctly")

            [:name, :title].each do |param|
                val = resource.send(param)
                assert(subscope.tags.include?(val),
                    "Scope was not tagged with %s '%s'" % [param, val])
            end
        end
    end

    # Testing the root cause of #615.  We should be using the fqname for the type, instead
    # of just the short name.
    def oldtest_fully_qualified_types
        parser = mkparser
        klass = parser.newclass("one::two")

        assert_equal("one::two", klass.classname, "Class did not get fully qualified class name")
    end
end
