#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/resourcetesting'

class TestResource < PuppetTest::TestCase
	include PuppetTest
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    Parser = Puppet::Parser
    AST = Parser::AST
    Resource = Puppet::Parser::Resource
    Reference = Puppet::Parser::Resource::Reference

    def setup
        super
        Puppet[:trace] = false
    end

    def test_initialize
        args = {:type => "resource", :title => "testing",
            :source => "source", :scope => "scope"}
        # Check our arg requirements
        args.each do |name, value|
            try = args.dup
            try.delete(name)
            assert_raise(ArgumentError, "Did not fail when %s was missing" % name) do
                Parser::Resource.new(try)
            end
        end

        Reference.expects(:new).with(:type => "resource", :title => "testing", :scope => "scope").returns(:ref)

        res = nil
        assert_nothing_raised do
            res = Parser::Resource.new(args)
        end
    end

    def test_merge
        res = mkresource
        other = mkresource

        # First try the case where the resource is not allowed to override
        res.source = "source1"
        other.source = "source2"
        other.source.expects(:child_of?).with("source1").returns(false)
        assert_raise(Puppet::ParseError, "Allowed unrelated resources to override") do
            res.merge(other)
        end

        # Next try it when the sources are equal.
        res.source = "source3"
        other.source = res.source
        other.source.expects(:child_of?).with("source3").never
        params = {:a => :b, :c => :d}
        other.expects(:params).returns(params)
        res.expects(:override_parameter).with(:b)
        res.expects(:override_parameter).with(:d)
        res.merge(other)

        # And then parentage is involved
        other = mkresource
        res.source = "source3"
        other.source = "source4"
        other.source.expects(:child_of?).with("source3").returns(true)
        params = {:a => :b, :c => :d}
        other.expects(:params).returns(params)
        res.expects(:override_parameter).with(:b)
        res.expects(:override_parameter).with(:d)
        res.merge(other)
    end

    # the [] method
    def test_array_accessors
        res = mkresource
        params = res.instance_variable_get("@params")
        assert_nil(res[:missing], "Found a missing parameter somehow")
        params[:something] = stub(:value => "yay")
        assert_equal("yay", res[:something], "Did not correctly call value on the parameter")

        res.expects(:title).returns(:mytitle)
        assert_equal(:mytitle, res[:title], "Did not call title when asked for it as a param")
    end

    # Make sure any defaults stored in the scope get added to our resource.
    def test_add_defaults
        res = mkresource
        params = res.instance_variable_get("@params")
        params[:a] = :b
        res.scope.expects(:lookupdefaults).with(res.type).returns(:a => :replaced, :c => :d)
        res.expects(:debug)

        res.send(:add_defaults)
        assert_equal(:d, params[:c], "Did not set default")
        assert_equal(:b, params[:a], "Replaced parameter with default")
    end

    def test_finish
        res = mkresource
        res.expects(:add_overrides)
        res.expects(:add_defaults)
        res.expects(:add_metaparams)
        res.expects(:validate)
        res.finish
    end

    # Make sure we paramcheck our params
    def test_validate
        res = mkresource
        params = res.instance_variable_get("@params")
        params[:one] = :two
        params[:three] = :four
        res.expects(:paramcheck).with(:one)
        res.expects(:paramcheck).with(:three)
        res.send(:validate)
    end

    def test_override_parameter
        res = mkresource
        params = res.instance_variable_get("@params")

        # There are three cases, with the second having two options:

        # No existing parameter.
        param = stub(:name => "myparam")
        res.send(:override_parameter, param)
        assert_equal(param, params["myparam"], "Override was not added to param list")

        # An existing parameter that we can override.
        source = stub(:child_of? => true)
        # Start out without addition
        params["param2"] = stub(:source => :whatever)
        param = stub(:name => "param2", :source => source, :add => false)
        res.send(:override_parameter, param)
        assert_equal(param, params["param2"], "Override was not added to param list")

        # Try with addition.
        params["param2"] = stub(:value => :a, :source => :whatever)
        param = stub(:name => "param2", :source => source, :add => true, :value => :b)
        param.expects(:value=).with([:a, :b])
        res.send(:override_parameter, param)
        assert_equal(param, params["param2"], "Override was not added to param list")

        # And finally, make sure we throw an exception when the sources aren't related
        source = stub(:child_of? => false)
        params["param2"] = stub(:source => :whatever, :file => :f, :line => :l)
        old = params["param2"]
        param = stub(:name => "param2", :source => source, :file => :f, :line => :l)
        assert_raise(Puppet::ParseError, "Did not fail when params conflicted") do
            res.send(:override_parameter, param)
        end
        assert_equal(old, params["param2"], "Param was replaced irrespective of conflict")
    end

    def test_set_parameter
        res = mkresource
        params = res.instance_variable_get("@params")

        # First test the simple case:  It's already a parameter
        param = mock('param')
        param.expects(:is_a?).with(Resource::Param).returns(true)
        param.expects(:name).returns("pname")
        res.send(:set_parameter, param)
        assert_equal(param, params["pname"], "Parameter was not added to hash")

        # Now the case where there's no value but it's not a param
        param = mock('param')
        param.expects(:is_a?).with(Resource::Param).returns(false)
        assert_raise(ArgumentError, "Did not fail when a non-param was passed") do
            res.send(:set_parameter, param)
        end

        # and the case where a value is passed in
        param = stub :name => "pname", :value => "whatever"
        Resource::Param.expects(:new).with(:name => "pname", :value => "myvalue", :source => res.source).returns(param)
        res.send(:set_parameter, "pname", "myvalue")
        assert_equal(param, params["pname"], "Did not put param in hash")
    end

    def test_paramcheck
        # There are three cases here:

        # It's a valid parameter
        res = mkresource
        ref = mock('ref')
        res.instance_variable_set("@ref", ref)
        klass = mock("class")
        ref.expects(:typeclass).returns(klass).times(4)
        klass.expects(:validattr?).with("good").returns(true)
        assert(res.send(:paramcheck, :good), "Did not allow valid param")

        # It's name or title
        klass.expects(:validattr?).with("name").returns(false)
        assert(res.send(:paramcheck, :name), "Did not allow name")
        klass.expects(:validattr?).with("title").returns(false)
        assert(res.send(:paramcheck, :title), "Did not allow title")

        # It's not actually allowed
        klass.expects(:validattr?).with("other").returns(false)
        res.expects(:fail)
        ref.expects(:type)
        res.send(:paramcheck, :other)
    end

    def test_to_trans
        # First try translating a builtin resource.  Make sure we use some references
        # and arrays, to make sure they translate correctly.
        refs = []
        4.times { |i| refs << Puppet::Parser::Resource::Reference.new(:title => "file%s" % i, :type => "file") }
        res = Parser::Resource.new :type => "file", :title => "/tmp",
            :source => @source, :scope => @scope,
            :params => paramify(@source, :owner => "nobody", :group => %w{you me},
            :require => refs[0], :ignore => %w{svn},
            :subscribe => [refs[1], refs[2]], :notify => [refs[3]])

        obj = nil
        assert_nothing_raised do
            obj = res.to_trans
        end

        assert_instance_of(Puppet::TransObject, obj)

        assert_equal(obj.type, res.type)
        assert_equal(obj.name, res.title)

        # TransObjects use strings, resources use symbols
        assert_equal("nobody", obj["owner"], "Single-value string was not passed correctly")
        assert_equal(%w{you me}, obj["group"], "Array of strings was not passed correctly")
        assert_equal("svn", obj["ignore"], "Array with single string was not turned into single value")
        assert_equal(["file", refs[0].title], obj["require"], "Resource reference was not passed correctly")
        assert_equal([["file", refs[1].title], ["file", refs[2].title]], obj["subscribe"], "Array of resource references was not passed correctly")
        assert_equal(["file", refs[3].title], obj["notify"], "Array with single resource reference was not turned into single value")
    end

    def test_evaluate
        @parser = mkparser
        # Make a definition that we know will, um, do something
        @parser.newdefine "evaltest",
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

    def test_add_overrides
        # Try it with nil
        res = mkresource
        res.scope = mock('scope')
        config = mock("config")
        res.scope.expects(:configuration).returns(config)
        config.expects(:resource_overrides).with(res).returns(nil)
        res.expects(:merge).never
        res.send(:add_overrides)

        # And an empty array
        res = mkresource
        res.scope = mock('scope')
        config = mock("config")
        res.scope.expects(:configuration).returns(config)
        config.expects(:resource_overrides).with(res).returns([])
        res.expects(:merge).never
        res.send(:add_overrides)

        # And with some overrides
        res = mkresource
        res.scope = mock('scope')
        config = mock("config")
        res.scope.expects(:configuration).returns(config)
        returns = %w{a b}
        config.expects(:resource_overrides).with(res).returns(returns)
        res.expects(:merge).with("a")
        res.expects(:merge).with("b")
        res.send(:add_overrides)
        assert(returns.empty?, "Did not clear overrides")
    end

    def test_proxymethods
        res = Parser::Resource.new :type => "evaltest", :title => "yay",
            :source => @source, :scope => @scope

        assert_equal("evaltest", res.type)
        assert_equal("yay", res.title)
        assert_equal(false, res.builtin?)
    end

    def test_add_metaparams
        res = mkresource
        params = res.instance_variable_get("@params")
        params[:a] = :b
        Puppet::Type.expects(:eachmetaparam).multiple_yields(:a, :b, :c)
        res.scope.expects(:lookupvar).with("b", false).returns(:something)
        res.scope.expects(:lookupvar).with("c", false).returns(:undefined)
        res.expects(:set_parameter).with(:b, :something)

        res.send(:add_metaparams)

        assert_nil(params[:c], "A value was created somehow for an unset metaparam")
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
        @parser = mkparser
        # Make a parent class with some defaults in it
        @parser.newclass("base",
            :code => defaultobj("file", :owner => "root", :group => "root")
        )

        # Now a mid-level class with some different values
        @parser.newclass("middle", :parent => "base",
            :code => defaultobj("file", :owner => "bin", :mode => "755")
        )

        # Now a lower class with its own defaults plus a resource
        @parser.newclass("bottom", :parent => "middle",
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
        @parser = mkparser
        define = @parser.newdefine "yayness",
            :code => resourcedef("file", "/tmp",
                "owner" => varref("name"), "mode" => varref("title"))

        klass = @parser.findclass("", "")
        should = {:name => :owner, :title => :mode}
        [
        {:name => "one", :title => "two"},
        {:title => "three"},
        ].each do |hash|
            scope = mkscope :parser => @parser
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
        @parser = mkparser
        define = @parser.newdefine("yayness",
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

# $Id$
