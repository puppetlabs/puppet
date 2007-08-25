#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

class TestCollector < Test::Unit::TestCase
	include PuppetTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    Parser = Puppet::Parser
    AST = Parser::AST

    def setup
        super
        Puppet[:trace] = false
        @scope = mkscope
        @compile = @scope.compile
    end

    # Test just collecting a specific resource.  This is used by the 'realize'
    # function, and it's much faster than iterating over all of the resources.
    def test_collect_resource
        # Make a collector
        coll = nil
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "file", nil, nil, :virtual)
        end

        # Now set the resource in the collector
        assert_nothing_raised do 
            coll.resources = ["File[/tmp/virtual1]", "File[/tmp/virtual3]"]
        end
        @compile.add_collection(coll)

        # Evaluate the collector and make sure it doesn't fail with no resources
        # found yet
        assert_nothing_raised("Resource collection with no results failed") do
            assert_equal(false, coll.evaluate)
        end

        # Make a couple of virtual resources
        one = mkresource(:type => "file", :title => "/tmp/virtual1",
            :virtual => true, :params => {:owner => "root"})
        two = mkresource(:type => "file", :title => "/tmp/virtual2",
            :virtual => true, :params => {:owner => "root"})
        @scope.setresource one
        @scope.setresource two

        # Now run the collector again and make sure it finds our resource
        assert_nothing_raised do
            assert_equal([one], coll.evaluate, "did not find resource")
        end

        # And make sure the resource is no longer virtual
        assert(! one.virtual?,
            "Resource is still virtual")

        # But the other still is
        assert(two.virtual?,
            "Resource got realized")

        # Make sure that the collection is still there
        assert(@compile.collections.include?(coll), "collection was deleted too soon")

        # Now add our third resource
        three = mkresource(:type => "file", :title => "/tmp/virtual3",
            :virtual => true, :params => {:owner => "root"})
        @scope.setresource three

        # Run the collection
        assert_nothing_raised do
            assert_equal([three], coll.evaluate, "did not find resource")
        end
        assert(! three.virtual?, "three is still virtual")

        # And make sure that the collection got deleted from the scope's list
        assert(@compile.collections.empty?, "collection was not deleted")
    end

    def test_virtual
        # Make a virtual resource
        virtual = mkresource(:type => "file", :title => "/tmp/virtual",
            :virtual => true, :params => {:owner => "root"})
        @scope.setresource virtual

        # And a non-virtual
        real = mkresource(:type => "file", :title => "/tmp/real",
            :params => {:owner => "root"})
        @scope.setresource real

        # Now make a collector
        coll = nil

        # Make a fake query
        code = proc do |res|
            true
        end
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "file", nil, code, :virtual)
        end

        # Set it in our scope
        @compile.add_collection(coll)

        # Make sure it's in the collections
        assert(@compile.collections.include?(coll), "collection was not added")

        # And try to collect the virtual resources.
        ret = nil
        assert_nothing_raised do
            ret = coll.collect_virtual
        end

        assert_equal([virtual], ret)

        # Now make sure evaluate does the right thing.
        assert_nothing_raised do
            ret = coll.evaluate
        end

        # And make sure our virtual object is no longer virtual
        assert(! virtual.virtual?, "Virtual object did not get realized")

        # Now make a new collector of a different type and make sure it
        # finds nothing.
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "exec", nil, nil, :virtual)
        end

        # Remark this as virtual
        virtual.virtual = true

        assert_nothing_raised do
            ret = coll.evaluate
        end

        assert_equal(false, ret)
    end

    # Collections that specify resources should be deleted when they succeed,
    # but others should remain until the very end.
    def test_normal_collections_remain
        # Make a collector
        coll = nil
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "file", nil, nil, :virtual)
        end

        @compile.add_collection(coll)

        # run the collection and make sure it doesn't get deleted, since it
        # didn't return anything
        assert_nothing_raised do
            assert_equal(false, coll.evaluate,
                "Evaluate returned incorrect value")
        end

        assert_equal([coll], @compile.collections, "Collection was deleted")

        # Make a resource
        one = mkresource(:type => "file", :title => "/tmp/virtual1",
            :virtual => true, :params => {:owner => "root"})
        @scope.setresource one

        # Now perform the collection again, and it should still be there
        assert_nothing_raised do
            assert_equal([one], coll.evaluate,
                "Evaluate returned incorrect value")
        end

        assert_equal([coll], @compile.collections, "Collection was deleted")

        assert_equal(false, one.virtual?, "One was not realized")
    end
end

# $Id$
