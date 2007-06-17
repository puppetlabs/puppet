#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppettest'
require 'puppettest/railstesting'
require 'puppettest/resourcetesting'


# A separate class for testing rails integration
class TestRailsCollection < PuppetTest::TestCase
    confine "Missing rails support" => Puppet.features.rails?
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

    def test_collect_exported
        railsinit

        # Set a hostname
        @scope.host = Facter.value(:hostname)

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

        # Make sure that the collection does not find the resource on the
        # next run.
        ret = nil
        assert_nothing_raised do
            ret = coll.collect_exported
        end

        assert(ret.empty?, "Exported resource was collected on the second run")


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

        assert(! ret, "got resources back")

        # Now create a whole new scope and make sure we can actually retrieve
        # the resource from the database, not just from the scope.
        # First create a host object and store our resource in it.

        # Now collect our facts
        facts = {}
        Facter.each do |fact, value| facts[fact] = value end 

        # Now try storing our crap
        # Remark this as exported
        exported.exported = true
        host = Puppet::Rails::Host.store(
            :resources => [exported],
            :facts => facts,
            :name => facts["hostname"]
        )
        assert(host, "did not get rails host")
        host.save

        # And make sure it's in there
        newres = host.resources.find_by_restype_and_title_and_exported("file", "/tmp/exported", true)
        assert(newres, "Did not find resource in db")
        interp, scope, source = mkclassframing
        scope.host = "two"

        # Now make a collector
        coll = nil
        assert_nothing_raised do
            coll = Puppet::Parser::Collector.new(scope, "file", nil, nil, :exported)
        end

        # Set it in our scope
        scope.newcollection(coll)

        # Make sure it's in the collections
        assert_equal([coll], scope.collections)

        # And try to collect the virtual resources.
        ret = nil
        assert_nothing_raised do
            ret = coll.collect_exported
        end

        assert_equal(["/tmp/exported"], ret.collect { |f| f.title })

        # Make sure we can evaluate the same collection multiple times and
        # that later collections do nothing
        assert_nothing_raised("Collection found same resource twice") do
            ret = coll.evaluate
        end
    end

    def test_collection_conflicts
        railsinit

        # First make a railshost we can conflict with
        host = Puppet::Rails::Host.new(:name => "myhost")

        host.resources.build(:title => "/tmp/conflicttest", :restype => "file",
            :exported => true)

        host.save

        # Now make a normal resource
        normal = mkresource(:type => "file", :title => "/tmp/conflicttest",
            :params => {:owner => "root"})
        @scope.setresource normal
        @scope.host = "otherhost"

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

        host.resources.build(:title => "/tmp/hosttest", :type => "file",
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

# $Id$
