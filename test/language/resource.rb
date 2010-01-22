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
        param = stub('param', :name => "pname")
        param.expects(:is_a?).with(Resource::Param).returns(true)
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
        klass.expects(:valid_parameter?).with("good").returns(true)
        assert(res.send(:paramcheck, :good), "Did not allow valid param")

        # It's name or title
        klass.expects(:valid_parameter?).with("name").returns(false)
        assert(res.send(:paramcheck, :name), "Did not allow name")
        klass.expects(:valid_parameter?).with("title").returns(false)
        assert(res.send(:paramcheck, :title), "Did not allow title")

        # It's not actually allowed
        klass.expects(:valid_parameter?).with("other").returns(false)
        res.expects(:fail)
        ref.expects(:type)
        res.send(:paramcheck, :other)
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


        klass = parser.find_hostclass("", "")
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
end
