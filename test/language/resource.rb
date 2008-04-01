#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

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

    def teardown
        mocha_verify
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

    def test_to_transobject
        # First try translating a builtin resource.  Make sure we use some references
        # and arrays, to make sure they translate correctly.
        source = mock("source")
        scope = mkscope
        scope.stubs(:tags).returns([])
        refs = []
        4.times { |i| refs << Puppet::Parser::Resource::Reference.new(:title => "file%s" % i, :type => "file") }
        res = Parser::Resource.new :type => "file", :title => "/tmp",
            :source => source, :scope => scope,
            :params => paramify(source, :owner => "nobody", :group => %w{you me},
            :require => refs[0], :ignore => %w{svn},
            :subscribe => [refs[1], refs[2]], :notify => [refs[3]])

        obj = nil
        assert_nothing_raised do
            obj = res.to_trans
        end

        assert_instance_of(Puppet::TransObject, obj)

        assert_equal(obj.type, res.type.downcase)
        assert_equal(obj.name, res.title)

        # TransObjects use strings, resources use symbols
        assert_equal("nobody", obj["owner"], "Single-value string was not passed correctly")
        assert_equal(%w{you me}, obj["group"], "Array of strings was not passed correctly")
        assert_equal("svn", obj["ignore"], "Array with single string was not turned into single value")
        assert_equal(["file", refs[0].title], obj["require"], "Resource reference was not passed correctly")
        assert_equal([["file", refs[1].title], ["file", refs[2].title]], obj["subscribe"], "Array of resource references was not passed correctly")
        assert_equal(["file", refs[3].title], obj["notify"], "Array with single resource reference was not turned into single value")
    end

    # FIXME This isn't a great test, but I need to move on.
    def test_to_transbucket
        bucket = mock("transbucket")
        source = mock("source")
        scope = mkscope
        res = Parser::Resource.new :type => "mydefine", :title => "yay",
            :source => source, :scope => scope


        result = res.to_trans
        assert_equal("yay", result.name, "did not set bucket name correctly")
        assert_equal("Mydefine", result.type, "did not set bucket type correctly")
    end

    def test_evaluate
        # First try the most common case, we're not a builtin type.
        res = mkresource
        ref = res.instance_variable_get("@ref")
        type = mock("type")
        ref.expects(:definedtype).returns(type)
        res.expects(:finish)
        res.scope = mock("scope")

        type.expects(:evaluate_code).with(res)

        res.evaluate
    end

    def test_proxymethods
        res = Parser::Resource.new :type => "evaltest", :title => "yay",
            :source => mock("source"), :scope => mkscope

        assert_equal("Evaltest", res.type)
        assert_equal("yay", res.title)
        assert_equal(false, res.builtin?)
    end

    def test_reference_conversion
        # First try it as a normal string
        ref = Parser::Resource::Reference.new(:type => "file", :title => "/tmp/ref1")

        # Now create an obj that uses it
        res = mkresource :type => "file", :title => "/tmp/resource",
            :params => {:require => ref}
        res.scope = mkscope

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
        res.scope = mkscope

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

        assert_nil(ref.builtintype, "Definition was considered builtin")
    end

    # The second part of #539 - make sure resources pass the arguments
    # correctly.
    def test_title_with_definitions
        parser = mkparser
        define = parser.newdefine "yayness",
            :code => resourcedef("file", "/tmp",
                "owner" => varref("name"), "mode" => varref("title"))


        klass = parser.findclass("", "")
        should = {:name => :owner, :title => :mode}
        [
        {:name => "one", :title => "two"},
        {:title => "three"},
        ].each do |hash|
            config = mkcompiler parser
            args = {:type => "yayness", :title => hash[:title],
                :source => klass, :scope => config.topscope}
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

            made = config.topscope.findresource("File[/tmp]")
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
            :source => mock("source"), :scope => mkscope,
            :params => {:owner => :undef, :mode => "755"}

        hash = nil
        assert_nothing_raised("Could not convert resource with undef to hash") do
            hash = res.to_hash
        end

        assert_nil(hash[:owner], "got a value for an undef parameter")
    end

    # #643 - Make sure virtual defines result in virtual resources
    def test_virtual_defines
        parser = mkparser
        define = parser.newdefine("yayness",
            :code => resourcedef("file", varref("name"),
                "mode" => "644"))

        config = mkcompiler(parser)

        res = mkresource :type => "yayness", :title => "foo", :params => {}, :scope => config.topscope
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
        res = mkresource :type => "yayness", :title => "bar", :params => {}, :scope => config.topscope
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
