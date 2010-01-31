#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'
require 'puppet/parser/parser'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/support/collection'

class TestAST < Test::Unit::TestCase
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::Support::Collection

    def test_if
        scope = mkscope
        astif = nil
        astelse = nil
        fakeelse = FakeAST.new(:else)
        faketest = FakeAST.new(true)
        fakeif = FakeAST.new(:if)

        assert_nothing_raised {
            astelse = AST::Else.new(:statements => fakeelse)
        }
        assert_nothing_raised {
            astif = AST::IfStatement.new(
                :test => faketest,
                :statements => fakeif,
                :else => astelse
            )
        }

        # We initialized it to true, so we should get that first
        ret = nil
        assert_nothing_raised {
            ret = astif.evaluate(scope)
        }
        assert_equal(:if, ret)

        # Now set it to false and check that
        faketest.evaluate = false
        assert_nothing_raised {
            ret = astif.evaluate(scope)
        }
        assert_equal(:else, ret)
    end

    # Make sure our override object behaves "correctly"
    def test_override
        scope = mkscope

        ref = nil
        assert_nothing_raised do
            ref = resourceoverride("file", "/yayness", "owner" => "blah", "group" => "boo")
        end

        Puppet::Parser::Resource.expects(:new).with { |type, title, o| o.is_a?(Hash) }.returns(:override)
        scope.compiler.expects(:add_override).with(:override)
        ret = nil
        assert_nothing_raised do
            ret = ref.evaluate scope
        end

        assert_equal(:override, ret, "Did not return override")
    end

    # make sure our resourcedefaults ast object works correctly.
    def test_resourcedefaults
        scope = mkscope

        # Now make some defaults for files
        args = {:source => "/yay/ness", :group => "yayness"}
        assert_nothing_raised do
            obj = defaultobj "file", args
            obj.evaluate scope
        end

        hash = nil
        assert_nothing_raised do
            hash = scope.lookupdefaults("File")
        end

        hash.each do |name, value|
            assert_instance_of(Symbol, name) # params always convert
            assert_instance_of(Puppet::Parser::Resource::Param, value)
        end

        args.each do |name, value|
            assert(hash[name], "Did not get default %s" % name)
            assert_equal(value, hash[name].value)
        end
    end

    def test_collection
        scope = mkscope

        coll = nil
        assert_nothing_raised do
            coll = AST::Collection.new(:type => "file", :form => :virtual)
        end

        assert_instance_of(AST::Collection, coll)

        ret = nil
        assert_nothing_raised do
            ret = coll.evaluate scope
        end

        assert_instance_of(Puppet::Parser::Collector, ret)

        # Now make sure we get it back from the scope
        colls = scope.compiler.instance_variable_get("@collections")
        assert_equal([ret], colls, "Did not store collector in config's collection list")
    end

    def test_virtual_collexp
        scope = mkscope

        # make a resource
        resource = mkresource(:type => "file", :title => "/tmp/testing",
            :scope => scope, :params => {:owner => "root", :group => "bin", :mode => "644"})

        run_collection_queries(:virtual) do |string, result, query|
            code = nil
            assert_nothing_raised do
                str, code = query.evaluate scope
            end

            assert_instance_of(Proc, code)
            assert_nothing_raised do
                assert_equal(result, code.call(resource),
                    "'#{string}' failed")
            end
        end
    end
end
