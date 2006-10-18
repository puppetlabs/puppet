#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet/rails'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'
require 'puppettest/railstesting'

class TestCollector < Test::Unit::TestCase
	include PuppetTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting
    Parser = Puppet::Parser
    AST = Parser::AST

    def setup
        super
        Puppet[:trace] = false
        @interp, @scope, @source = mkclassframing
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
        @scope.newcollection(coll)

        # Make sure it's in the collections
        assert_equal([coll], @scope.collections)

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

        # Make sure it got deleted from the collection list
        assert_equal([], @scope.collections)

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

        assert_equal([], ret)
    end

    if defined? ActiveRecord::Base
    def test_collect_exported
        railsinit
        # make an exported resource
        exported = mkresource(:type => "file", :title => "/tmp/exported",
            :exported => true, :params => {:owner => "root"})
        @scope.setresource exported

        assert(exported.exported?, "Object was not marked exported")
        assert(exported.virtual?, "Object was not marked virtual")

        # And a non-exported
        real = mkresource(:type => "file", :title => "/tmp/real",
            :params => {:owner => "root"})
        @scope.setresource real

        # Now make a collector
        coll = nil
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "file", nil, nil, :exported)
        end

        # Set it in our scope
        @scope.newcollection(coll)

        # Make sure it's in the collections
        assert_equal([coll], @scope.collections)

        # And try to collect the virtual resources.
        ret = nil
        assert_nothing_raised do
            ret = coll.collect_exported
        end

        assert_equal([exported], ret)

        # Now make sure evaluate does the right thing.
        assert_nothing_raised do
            ret = coll.evaluate
        end

        # Make sure it got deleted from the collection list
        assert_equal([], @scope.collections)

        # And make sure our exported object is no longer exported
        assert(! exported.virtual?, "Virtual object did not get realized")

        # But it should still be marked exported.
        assert(exported.exported?, "Resource got un-exported")

        # Now make a new collector of a different type and make sure it
        # finds nothing.
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "exec", nil, nil, :exported)
        end

        # Remark this as virtual
        exported.virtual = true

        assert_nothing_raised do
            ret = coll.evaluate
        end

        assert_equal([], ret)
    end

    def test_collection_conflicts
        railsinit

        # First make a railshost we can conflict with
        host = Puppet::Rails::Host.new(:name => "myhost")

        host.rails_resources.build(:title => "/tmp/conflicttest", :restype => "file",
            :exported => true)

        host.save

        # Now make a normal resource
        normal = mkresource(:type => "file", :title => "/tmp/conflicttest",
            :params => {:owner => "root"})
        @scope.setresource normal

        # Now make a collector
        coll = nil
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "file", nil, nil, :exported)
        end

        # And try to collect the virtual resources.
        assert_raise(Puppet::ParseError) do
            ret = coll.collect_exported
        end
    end

    # Make sure we do not collect resources from the host we're on
    def test_no_resources_from_me
        railsinit

        # Make our configuration
        host = Puppet::Rails::Host.new(:name => "myhost")

        host.rails_resources.build(:title => "/tmp/hosttest", :restype => "file",
            :exported => true)

        host.save

        @scope.host = "myhost"

        # Now make a collector
        coll = nil
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(@scope, "file", nil, nil, :exported)
        end

        # And make sure we get nada back
        ret = nil
        assert_nothing_raised do
            ret = coll.collect_exported
        end

        assert(ret.empty?, "Found exports from our own host")
    end
    end
end

# $Id$
