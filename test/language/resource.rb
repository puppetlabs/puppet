#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/railstesting'

class TestResource < PuppetTest::TestCase
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
        result = @scope.findresource("File[/tmp]")
        
        # Now make sure we got the code we expected.
        assert_instance_of(Puppet::Parser::Resource, result)

        assert_equal("file", result.type)
        assert_equal("/tmp", result.title)
        assert_equal("nobody", result["owner"])
        assert_equal("755", result["mode"])

        # And that we cannot find the old resource
        assert_nil(@scope.findresource("Evaltest[yay]"),
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
            :source => @source, :scope => @scope,
            :params => paramify(@source, :tag => "yay")

        assert_nil(res[:schedule], "Got schedule already")
        assert_nothing_raised do
            res.addmetaparams
        end
        @scope.setvar("schedule", "daily")

        # This is so we can test that it won't override already-set metaparams
        @scope.setvar("tag", "funtest")

        assert_nothing_raised do
            res.addmetaparams
        end

        assert_equal("daily", res[:schedule], "Did not get metaparam")
        assert_equal("yay", res[:tag], "Overrode explicitly-set metaparam")
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

    # #472.  Really, this still isn't the best behaviour, but at least
    # it's consistent with what we have elsewhere.
    def test_defaults_from_parent_classes
        # Make a parent class with some defaults in it
        @interp.newclass("base",
            :code => defaultobj("file", :owner => "root", :group => "root")
        )

        # Now a mid-level class with some different values
        @interp.newclass("middle", :parent => "base",
            :code => defaultobj("file", :owner => "bin", :mode => "755")
        )

        # Now a lower class with its own defaults plus a resource
        @interp.newclass("bottom", :parent => "middle",
            :code => AST::ASTArray.new(:children => [
                defaultobj("file", :owner => "adm", :recurse => "true"),
                resourcedef("file", "/tmp/yayness", {})
            ])
        )

        # Now evaluate the class.
        assert_nothing_raised("Failed to evaluate class tree") do
            @scope.evalclasses("bottom")
        end

        # Make sure our resource got created.
        res = @scope.findresource("File[/tmp/yayness]")
        assert_nothing_raised("Could not add defaults") do
            res.adddefaults
        end
        assert(res, "could not find resource")
        {:owner => "adm", :recurse => "true", :group => "root", :mode => "755"}.each do |param, value|
            assert_equal(value, res[param], "%s => %s did not inherit correctly" %
                [param, value])
        end
    end

    # The second part of #539 - make sure resources pass the arguments
    # correctly.
    def test_title_with_definitions
        define = @interp.newdefine "yayness",
            :code => resourcedef("file", "/tmp",
                "owner" => varref("name"), "mode" => varref("title"))

        klass = @interp.findclass("", "")
        should = {:name => :owner, :title => :mode}
        [
        {:name => "one", :title => "two"},
        {:title => "three"},
        ].each do |hash|
            scope = mkscope :interp => @interp
            args = {:type => "yayness", :title => hash[:title],
                :source => klass, :scope => scope}
            if hash[:name]
                args[:params] = {:name => hash[:name]}
            else
                args[:params] = {} # override the defaults
            end

            res = nil
            assert_nothing_raised("Could not create res with %s" % hash.inspect) do
                res = mkresource(args)
            end
            assert_nothing_raised("Could not eval res with %s" % hash.inspect) do
                res.evaluate
            end

            made = scope.findresource("File[/tmp]")
            assert(made, "Did not create resource with %s" % hash.inspect)
            should.each do |orig, param|
                assert_equal(hash[orig] || hash[:title], made[param],
                    "%s was not set correctly with %s" % [param, hash.inspect])
            end
        end
    end

    # part of #629 -- the undef keyword.  Make sure 'undef' params get skipped.
    def test_undef_and_to_hash
        res = mkresource :type => "file", :title => "/tmp/testing",
            :source => @source, :scope => @scope,
            :params => {:owner => :undef, :mode => "755"}

        hash = nil
        assert_nothing_raised("Could not convert resource with undef to hash") do
            hash = res.to_hash
        end

        assert_nil(hash[:owner], "got a value for an undef parameter")
    end

    # #643 - Make sure virtual defines result in virtual resources
    def test_virtual_defines
        define = @interp.newdefine("yayness",
            :code => resourcedef("file", varref("name"),
                "mode" => "644"))

        res = mkresource :type => "yayness", :title => "foo", :params => {}
        res.virtual = true

        result = nil
        assert_nothing_raised("Could not evaluate defined resource") do
            result = res.evaluate
        end

        scope = res.scope
        newres = scope.findresource("File[foo]")
        assert(newres, "Could not find resource")

        assert(newres.virtual?, "Virtual defined resource generated non-virtual resources")

        # Now try it with exported resources
        res = mkresource :type => "yayness", :title => "bar", :params => {}
        res.exported = true

        result = nil
        assert_nothing_raised("Could not evaluate exported resource") do
            result = res.evaluate
        end

        scope = res.scope
        newres = scope.findresource("File[bar]")
        assert(newres, "Could not find resource")

        assert(newres.exported?, "Exported defined resource generated non-exported resources")
        assert(newres.virtual?, "Exported defined resource generated non-virtual resources")
    end
end

# A separate class for testing rails integration
class TestExportedResources < TestResource
    confine "Missing rails support" => Puppet.features.rails?

    # Compare a parser resource to a rails resource.
    def compare_resources(host, res, updating, options = {})
        # to_rails now expects to be passed a resource, else it will create a new one
        newobj = host.resources.find_by_restype_and_title(res.type, res.title)
        assert_nothing_raised do
            newobj = res.to_rails(host, newobj)
        end

        assert_instance_of(Puppet::Rails::Resource, newobj)
        newobj.save

        if updating
            tail = "on update"
        else
            tail = ""
        end

        # Make sure we find our object and only our object
        count = 0
        obj = nil
        Puppet::Rails::Resource.find(:all).each do |obj|
            assert_equal(newobj.id, obj.id, "Found object has a different id than generated object %s" % tail)
            count += 1
            [:title, :restype, :line, :exported].each do |param|
                if param == :restype
                    method = :type
                else
                    method = param
                end
                assert_equal(res.send(method), obj[param], 
                    "attribute %s was not set correctly in rails %s" % [param, tail])
            end
        end
        assert_equal(1, count, "Got too many resources %s" % tail)
        # Now make sure we can find it again
        assert_nothing_raised do
            obj = Puppet::Rails::Resource.find_by_restype_and_title(
                res.type, res.title, :include => :param_names
            )
        end
        assert_instance_of(Puppet::Rails::Resource, obj)

        # Make sure we get the parameters back
        params = options[:params] || [obj.param_names.collect { |p| p.name },
            res.to_hash.keys].flatten.collect { |n| n.to_s }.uniq

        params.each do |name|
            param = obj.param_names.find_by_name(name)
            if res[name]
                assert(param, "resource did not keep %s %s" % [name, tail])
            else
                assert(! param, "resource did not delete %s %s" % [name, tail])
            end
            if param
                values = param.param_values.collect { |pv| pv.value }
                should = res[param.name]
                should = [should] unless should.is_a?(Array)
                assert_equal(should, values,
                    "%s was different %s" % [param.name, tail])
            end
        end
    end

    def test_to_rails
        railsteardown
        railsinit
        res = mkresource :type => "file", :title => "/tmp/testing",
            :source => @source, :scope => @scope,
            :params => {:owner => "root", :source => ["/tmp/A", "/tmp/B"],
                :mode => "755"}

        res.line = 50

        # We also need a Rails Host to store under
        host = Puppet::Rails::Host.new(:name => Facter.hostname)

        compare_resources(host, res, false, :params => %w{owner source mode})

        # Now make some changes to our resource.  We're removing the mode,
        # changing the source, and adding 'check'.
        res = mkresource :type => "file", :title => "/tmp/testing",
            :source => @source, :scope => @scope,
            :params => {:owner => "bin", :source => ["/tmp/A", "/tmp/C"],
            :check => "checksum"}

        res.line = 75
        res.exported = true

        compare_resources(host, res, true, :params => %w{owner source mode check})
    end
end

# $Id$
