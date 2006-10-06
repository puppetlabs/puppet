#!/usr/bin/ruby

require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/railstesting'

class TestResource < Test::Unit::TestCase
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

    def test_initialize
        args = {:type => "resource", :title => "testing",
            :source => @source, :scope => @scope}
        # Check our arg requirements
        args.each do |name, value|
            try = args.dup
            try.delete(name)
            assert_raise(Puppet::DevError) do
                Parser::Resource.new(try)
            end
        end

        args[:params] = paramify @source, :one => "yay", :three => "rah"

        res = nil
        assert_nothing_raised do
            res = Parser::Resource.new(args)
        end

        # Make sure it got the parameters correctly.
        assert_equal("yay", res[:one])
        assert_equal("rah", res[:three])

        assert_equal({:one => "yay", :three => "rah"}, res.to_hash)
    end

    def test_override
        res = mkresource

        # Now verify we can't override with any random class
        assert_raise(Puppet::ParseError) do
            res.set paramify(@scope.findclass("other"), "one" => "boo").shift
        end

        # And that we can with a subclass
        assert_nothing_raised do
            res.set paramify(@scope.findclass("sub1"), "one" => "boo").shift
        end

        # And that a different subclass can override a different parameter
        assert_nothing_raised do
            res.set paramify(@scope.findclass("sub2"), "three" => "boo").shift
        end

        # But not the same one
        assert_raise(Puppet::ParseError) do
            res.set paramify(@scope.findclass("sub2"), "one" => "something").shift
        end
    end

    def test_merge
        # Start with the normal one
        res = mkresource

        # Now create a resource from a different scope
        other = mkresource :source => other, :params => {"one" => "boo"}

        # Make sure we can't merge it
        assert_raise(Puppet::ParseError) do
            res.merge(other)
        end

        # Make one from a subscope
        other = mkresource :source => "sub1", :params => {"one" => "boo"}

        # Make sure it merges
        assert_nothing_raised do
            res.merge(other)
        end

        assert_equal("boo", res["one"])
    end

    def test_paramcheck
        # First make a builtin resource
        res = nil
        assert_nothing_raised do
            res = Parser::Resource.new :type => "file", :title => tempfile(),
                :source => @source, :scope => @scope
        end

        %w{path group source schedule subscribe}.each do |param|
            assert_nothing_raised("Param %s was considered invalid" % param) do
                res.paramcheck(param)
            end
        end

        %w{this bad noness}.each do |param|
            assert_raise(Puppet::ParseError, "%s was considered valid" % param) do
                res.paramcheck(param)
            end
        end

        # Now create a defined resource
        assert_nothing_raised do
            res = Parser::Resource.new :type => "resource", :title => "yay",
                :source => @source, :scope => @scope
        end

        %w{one two three schedule subscribe}.each do |param|
            assert_nothing_raised("Param %s was considered invalid" % param) do
                res.paramcheck(param)
            end
        end

        %w{this bad noness}.each do |param|
            assert_raise(Puppet::ParseError, "%s was considered valid" % param) do
                res.paramcheck(param)
            end
        end
    end

    def test_to_trans
        # First try translating a builtin resource
        res = Parser::Resource.new :type => "file", :title => "/tmp",
            :source => @source, :scope => @scope,
            :params => paramify(@source, :owner => "nobody", :mode => "644")

        obj = nil
        assert_nothing_raised do
            obj = res.to_trans
        end

        assert_instance_of(Puppet::TransObject, obj)

        assert_equal(obj.type, res.type)
        assert_equal(obj.name, res.title)

        # TransObjects use strings, resources use symbols
        hash = obj.to_hash.inject({}) { |h,a| h[a[0].intern] = a[1]; h }
        assert_equal(hash, res.to_hash)
    end

    def test_adddefaults
        # Set some defaults at the top level
        top = {:one => "fun", :two => "shoe"}

        @scope.setdefaults("resource", paramify(@source, top))

        # Make a resource at that level
        res = Parser::Resource.new :type => "resource", :title => "yay",
            :source => @source, :scope => @scope

        # Add the defaults
        assert_nothing_raised do
            res.adddefaults
        end

        # And make sure we got them
        top.each do |p, v|
            assert_equal(v, res[p])
        end

        # Now got a bit lower
        other = @scope.newscope

        # And create a resource
        lowerres = Parser::Resource.new :type => "resource", :title => "funtest",
            :source => @source, :scope => other

        assert_nothing_raised do
            lowerres.adddefaults
        end

        # And check
        top.each do |p, v|
            assert_equal(v, lowerres[p])
        end

        # Now add some of our own defaults
        lower = {:one => "shun", :three => "free"}
        other.setdefaults("resource", paramify(@source, lower))
        otherres = Parser::Resource.new :type => "resource", :title => "yaytest",
            :source => @source, :scope => other

        should = top.dup
        # Make sure the lower defaults beat the higher ones.
        lower.each do |p, v| should[p] = v end

        otherres.adddefaults

        should.each do |p,v|
            assert_equal(v, otherres[p])
        end
    end

    def test_evaluate
        # Make a definition that we know will, um, do something
        @interp.newdefine "evaltest",
            :arguments => [%w{one}, ["two", stringobj("755")]],
            :code => resourcedef("file", "/tmp",
                "owner" => varref("one"), "mode" => varref("two"))

        res = Parser::Resource.new :type => "evaltest", :title => "yay",
            :source => @source, :scope => @scope,
            :params => paramify(@source, :one => "nobody")

        # Now try evaluating
        ret = nil
        assert_nothing_raised do
            ret = res.evaluate
        end

        # Make sure we can find our object now
        result = @scope.findresource("file[/tmp]")
        
        # Now make sure we got the code we expected.
        assert_instance_of(Puppet::Parser::Resource, result)

        assert_equal("file", result.type)
        assert_equal("/tmp", result.title)
        assert_equal("nobody", result["owner"])
        assert_equal("755", result["mode"])

        # And that we cannot find the old resource
        assert_nil(@scope.findresource("evaltest[yay]"),
            "Evaluated resource was not deleted")
    end

    def test_addoverrides
        # First create an override for an object that doesn't yet exist
        over1 = mkresource :source => "sub1", :params => {:one => "yay"}

        assert_nothing_raised do
            @scope.setoverride(over1)
        end

        assert(over1.override, "Override was not marked so")

        # Now make the resource
        res = mkresource :source => "base", :params => {:one => "rah",
            :three => "foo"}

        # And add it to our scope
        @scope.setresource(res)

        # And make sure over1 has not yet taken affect
        assert_equal("foo", res[:three], "Lost value")

        # Now add an immediately binding override
        over2 = mkresource :source => "sub1", :params => {:three => "yay"}

        assert_nothing_raised do
            @scope.setoverride(over2)
        end

        # And make sure it worked
        assert_equal("yay", res[:three], "Override 2 was ignored")

        # Now add our late-binding override
        assert_nothing_raised do
            res.addoverrides
        end

        # And make sure they're still around
        assert_equal("yay", res[:one], "Override 1 lost")
        assert_equal("yay", res[:three], "Override 2 lost")

        # And finally, make sure that there are no remaining overrides
        assert_nothing_raised do
            res.addoverrides
        end
    end

    def test_proxymethods
        res = Parser::Resource.new :type => "evaltest", :title => "yay",
            :source => @source, :scope => @scope

        assert_equal("evaltest", res.type)
        assert_equal("yay", res.title)
        assert_equal(false, res.builtin?)
    end

    def test_addmetaparams
        mkevaltest @interp
        res = Parser::Resource.new :type => "evaltest", :title => "yay",
            :source => @source, :scope => @scope

        assert_nil(res[:schedule], "Got schedule already")
        assert_nothing_raised do
            res.addmetaparams
        end
        @scope.setvar("schedule", "daily")

        assert_nothing_raised do
            res.addmetaparams
        end

        assert_equal("daily", res[:schedule], "Did not get metaparam")
        assert_nil(res[:noop], "Got invalid metaparam")
    end

    def test_reference_conversion
        # First try it as a normal string
        ref = Parser::Resource::Reference.new(:type => "file", :title => "/tmp/ref1")

        # Now create an obj that uses it
        res = mkresource :type => "file", :title => "/tmp/resource",
            :params => {:require => ref}

        trans = nil
        assert_nothing_raised do
            trans = res.to_trans
        end

        assert_instance_of(Array, trans["require"])
        assert_equal(["file", "/tmp/ref1"], trans["require"])

        # Now try it when using an array of references.
        two = Parser::Resource::Reference.new(:type => "file", :title => "/tmp/ref2")
        res = mkresource :type => "file", :title => "/tmp/resource2",
            :params => {:require => [ref, two]}

        trans = nil
        assert_nothing_raised do
            trans = res.to_trans
        end

        assert_instance_of(Array, trans["require"][0])
        trans["require"].each do |val|
            assert_instance_of(Array, val)
            assert_equal("file", val[0])
            assert(val[1] =~ /\/tmp\/ref[0-9]/,
                "Was %s instead of the file name" % val[1])
        end
    end

    # This is a bit of a weird one -- the user should not actually know
    # that components exist, so we want references to act like they're not
    # builtin
    def test_components_are_not_builtin
        ref = Parser::Resource::Reference.new(:type => "component", :title => "yay")

        assert_nil(ref.builtintype, "Component was considered builtin")
    end
    if defined? ActiveRecord::Base
    def test_store
        railsinit
        res = mkresource :type => "file", :title => "/tmp/testing",
            :source => @source, :scope => @scope,
            :params => {:owner => "root", :mode => "755"}

        # We also need a Rails Host to store under
        host = Puppet::Rails::Host.new(:name => Facter.hostname)

        obj = nil
        assert_nothing_raised do
            obj = res.store(host)
        end

        assert_instance_of(Puppet::Rails::RailsResource, obj)

        assert_nothing_raised do
            Puppet::Util.benchmark(:info, "Saved host") do
                host.save
            end
        end

        # Now make sure we can find it again
        assert_nothing_raised do
            obj = Puppet::Rails::RailsResource.find_by_host_id_and_restype_and_title(
                host.id, res.type, res.title
            )
        end
        assert_instance_of(Puppet::Rails::RailsResource, obj)

        # Make sure we get the parameters back
        obj.rails_parameters.each do |param|
            assert_equal(res[param[:name]], param[:value],
                "%s was different" % param[:name])
        end
    end
    end
end

# $Id$
