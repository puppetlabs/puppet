#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'mocha'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

# so, what kind of things do we want to test?

# we don't need to test function, since we're confident in the
# library tests.  We do, however, need to test how things are actually
# working in the language.

# so really, we want to do things like test that our ast is correct
# and test whether we've got things in the right scopes

class TestScope < Test::Unit::TestCase
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting

    def to_ary(hash)
        hash.collect { |key,value|
            [key,value]
        }
    end

    def test_variables
        config = mkcompiler
        topscope = config.topscope
        midscope = config.newscope(topscope)
        botscope = config.newscope(midscope)

        scopes = {:top => topscope, :mid => midscope, :bot => botscope}

        # Set a variable in the top and make sure all three can get it
        topscope.setvar("first", "topval")
        scopes.each do |name, scope|
            assert_equal("topval", scope.lookupvar("first", false), "Could not find var in %s" % name)
        end

        # Now set a var in the midscope and make sure the mid and bottom can see it but not the top
        midscope.setvar("second", "midval")
        assert_equal(:undefined, scopes[:top].lookupvar("second", false), "Found child var in top scope")
        [:mid, :bot].each do |name|
            assert_equal("midval", scopes[name].lookupvar("second", false), "Could not find var in %s" % name)
        end

        # And set something in the bottom, and make sure we only find it there.
        botscope.setvar("third", "botval")
        [:top, :mid].each do |name|
            assert_equal(:undefined, scopes[name].lookupvar("third", false), "Found child var in top scope")
        end
        assert_equal("botval", scopes[:bot].lookupvar("third", false), "Could not find var in bottom scope")


        # Test that the scopes convert to hash structures correctly.
        # For topscope recursive vs non-recursive should be identical
        assert_equal(topscope.to_hash(false), topscope.to_hash(true),
                     "Recursive and non-recursive hash is identical for topscope")

        # Check the variable we expect is present.
        assert_equal({"first" => "topval"}, topscope.to_hash(),
                     "topscope returns the expected hash of variables")

        # Now, check that midscope does the right thing in all cases.
        assert_equal({"second" => "midval"},
                     midscope.to_hash(false),
                     "midscope non-recursive hash contains only midscope variable")
        assert_equal({"first" => "topval", "second" => "midval"},
                     midscope.to_hash(true),
                     "midscope recursive hash contains topscope variable also")

        # Finally, check the ability to shadow symbols by adding a shadow to
        # bottomscope, then checking that we see the right stuff.
        botscope.setvar("first", "shadowval")
        assert_equal({"third" => "botval", "first" => "shadowval"},
                     botscope.to_hash(false),
                     "botscope has the right non-recursive hash")
        assert_equal({"third" => "botval", "first" => "shadowval", "second" => "midval"},
                     botscope.to_hash(true),
                     "botscope values shadow parent scope values")
    end

    def test_declarative
        # set to declarative
        top = mkscope
        sub = mkscope(:parent => top)

        assert_nothing_raised {
            top.setvar("test","value")
        }
        assert_raise(Puppet::ParseError) {
            top.setvar("test","other")
        }
        assert_nothing_raised {
            sub.setvar("test","later")
        }
        assert_raise(Puppet::ParseError) {
            top.setvar("test","yeehaw")
        }
    end

    def test_setdefaults
        config = mkcompiler

        scope = config.topscope

        defaults = scope.instance_variable_get("@defaults")

        # First the case where there are no defaults and we pass a single param
        param = stub :name => "myparam", :file => "f", :line => "l"
        scope.setdefaults(:mytype, param)
        assert_equal({"myparam" => param}, defaults[:mytype], "Did not set default correctly")

        # Now the case where we pass in multiple parameters
        param1 = stub :name => "one", :file => "f", :line => "l"
        param2 = stub :name => "two", :file => "f", :line => "l"
        scope.setdefaults(:newtype, [param1, param2])
        assert_equal({"one" => param1, "two" => param2}, defaults[:newtype], "Did not set multiple defaults correctly")

        # And the case where there's actually a conflict.  Use the first default for this.
        newparam = stub :name => "myparam", :file => "f", :line => "l"
        assert_raise(Puppet::ParseError, "Allowed resetting of defaults") do
            scope.setdefaults(:mytype, param)
        end
        assert_equal({"myparam" => param}, defaults[:mytype], "Replaced default even though there was a failure")
    end

    def test_lookupdefaults
        config = mkcompiler
        top = config.topscope

        # Make a subscope
        sub = config.newscope(top)

        topdefs = top.instance_variable_get("@defaults")
        subdefs = sub.instance_variable_get("@defaults")

        # First add some defaults to our top scope
        topdefs[:t1] = {:p1 => :p2, :p3 => :p4}
        topdefs[:t2] = {:p5 => :p6}

        # Then the sub scope
        subdefs[:t1] = {:p1 => :p7, :p8 => :p9}
        subdefs[:t2] = {:p5 => :p10, :p11 => :p12}

        # Now make sure we get the correct list back
        result = nil
        assert_nothing_raised("Could not get defaults") do
            result = sub.lookupdefaults(:t1)
        end
        assert_equal(:p9, result[:p8], "Did not get child defaults")
        assert_equal(:p4, result[:p3], "Did not override parent defaults with child default")
        assert_equal(:p7, result[:p1], "Did not get parent defaults")
    end

    def test_parent
        config = mkcompiler
        top = config.topscope

        # Make a subscope
        sub = config.newscope(top)

        assert_equal(top, sub.parent, "Did not find parent scope correctly")
        assert_equal(top, sub.parent, "Did not find parent scope on second call")
    end

    def test_strinterp
        # Make and evaluate our classes so the qualified lookups work
        parser = mkparser
        klass = parser.newclass("")
        scope = mkscope(:parser => parser)
        Puppet::Parser::Resource.new(:type => "class", :title => :main, :scope => scope, :source => mock('source')).evaluate

        assert_nothing_raised {
            scope.setvar("test","value")
        }

        scopes = {"" => scope}

        %w{one one::two one::two::three}.each do |name|
            klass = parser.newclass(name)
            Puppet::Parser::Resource.new(:type => "class", :title => name, :scope => scope, :source => mock('source')).evaluate
            scopes[name] = scope.compiler.class_scope(klass)
            scopes[name].setvar("test", "value-%s" % name.sub(/.+::/,''))
        end

        assert_equal("value", scope.lookupvar("::test"), "did not look up qualified value correctly")
        tests = {
            "string ${test}" => "string value",
            "string ${one::two::three::test}" => "string value-three",
            "string $one::two::three::test" => "string value-three",
            "string ${one::two::test}" => "string value-two",
            "string $one::two::test" => "string value-two",
            "string ${one::test}" => "string value-one",
            "string $one::test" => "string value-one",
            "string ${::test}" => "string value",
            "string $::test" => "string value",
            "string ${test} ${test} ${test}" => "string value value value",
            "string $test ${test} $test" => "string value value value",
            "string \\$test" => "string $test",
            '\\$test string' => "$test string",
            '$test string' => "value string",
            'a testing $' => "a testing $",
            'a testing \$' => "a testing $",
            "an escaped \\\n carriage return" => "an escaped  carriage return",
            '\$' => "$",
            '\s' => "\s",
            '\t' => "\t",
            '\n' => "\n"
        }

        tests.each do |input, output|
            assert_nothing_raised("Failed to scan %s" % input.inspect) do
                assert_equal(output, scope.strinterp(input),
                    'did not parserret %s correctly' % input.inspect)
            end
        end

        logs = []
        Puppet::Util::Log.close
        Puppet::Util::Log.newdestination(logs)

        # #523
        %w{d f h l w z}.each do |l|
            string = "\\" + l
            assert_nothing_raised do
                assert_equal(string, scope.strinterp(string),
                    'did not parserret %s correctly' % string)
            end

            assert(logs.detect { |m| m.message =~ /Unrecognised escape/ },
                "Did not get warning about escape sequence with %s" % string)
            logs.clear
        end
    end

    def test_tagfunction
        Puppet::Parser::Functions.function(:tag)
        scope = mkscope
        resource = mock 'resource'
        scope.resource = resource
        resource.expects(:tag).with("yayness", "booness")

        scope.function_tag(%w{yayness booness})
    end

    def test_includefunction
        parser = mkparser
        scope = mkscope :parser => parser

        myclass = parser.newclass "myclass"
        otherclass = parser.newclass "otherclass"

        function = Puppet::Parser::AST::Function.new(
            :name => "include",
            :ftype => :statement,
            :arguments => AST::ASTArray.new(
                :children => [nameobj("myclass"), nameobj("otherclass")]
            )
        )

        assert_nothing_raised do
            function.evaluate scope
        end

        scope.compiler.send(:evaluate_generators)

        [myclass, otherclass].each do |klass|
            assert(scope.compiler.class_scope(klass),
                "%s was not set" % klass.classname)
        end
    end

    def test_definedfunction
        Puppet::Parser::Functions.function(:defined)
        parser = mkparser
        %w{one two}.each do |name|
            parser.newdefine name
        end

        scope = mkscope :parser => parser

        assert_nothing_raised {
            %w{one two file user}.each do |type|
                assert(scope.function_defined([type]),
                    "Class #{type} was not considered defined")
            end

            assert(!scope.function_defined(["nopeness"]),
                "Class 'nopeness' was incorrectly considered defined")
        }
    end

    # Make sure we know what we consider to be truth.
    def test_truth
        assert_equal(true, Puppet::Parser::Scope.true?("a string"),
            "Strings not considered true")
        assert_equal(true, Puppet::Parser::Scope.true?(true),
            "True considered true")
        assert_equal(false, Puppet::Parser::Scope.true?(""),
            "Empty strings considered true")
        assert_equal(false, Puppet::Parser::Scope.true?(false),
            "false considered true")
        assert_equal(false, Puppet::Parser::Scope.true?(:undef),
            "undef considered true")
    end

    # Verify that we recursively mark as exported the results of collectable
    # components.
    def test_virtual_definitions_do_not_get_evaluated
        config = mkcompiler
        parser = config.parser

        # Create a default source
        config.topscope.source = parser.newclass "", ""

        # And a scope resource
        scope_res = stub 'scope_resource', :virtual? => true, :exported? => false, :tags => [], :builtin? => true, :type => "eh", :title => "bee"
        config.topscope.resource = scope_res

        args = AST::ASTArray.new(
            :file => tempfile(),
            :line => rand(100),
            :children => [nameobj("arg")]
        )

        # Create a top-level define
        parser.newdefine "one", :arguments => [%w{arg}],
            :code => AST::ASTArray.new(
                :children => [
                    resourcedef("file", "/tmp", {"owner" => varref("arg")})
                ]
            )

        # create a resource that calls our third define
        obj = resourcedef("one", "boo", {"arg" => "parentfoo"})

        # And mark it as virtual
        obj.virtual = true

        # And then evaluate it
        obj.evaluate config.topscope

        # And run the loop.
        config.send(:evaluate_generators)

        %w{File}.each do |type|
            objects = config.resources.find_all { |r| r.type == type and r.virtual }

            assert(objects.empty?, "Virtual define got evaluated")
        end
    end

    if defined? ::ActiveRecord
    # Verify that we can both store and collect an object in the same
    # run, whether it's in the same scope as a collection or a different
    # scope.
    def test_storeandcollect
        catalog_cache_class = Puppet::Resource::Catalog.indirection.cache_class
        facts_cache_class = Puppet::Node::Facts.indirection.cache_class
        node_cache_class = Puppet::Node.indirection.cache_class
        Puppet[:storeconfigs] = true
        Puppet::Rails.init
        sleep 1
        children = []
        Puppet[:code] = "
class yay {
    @@host { myhost: ip => \"192.168.0.2\" }
}
include yay
@@host { puppet: ip => \"192.168.0.3\" }
Host <<||>>"

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new
        }

        config = nil
        # We run it twice because we want to make sure there's no conflict
        # if we pull it up from the database.
        node = mknode
        node.parameters = {"hostname" => node.name}
        2.times { |i|
            assert_nothing_raised {
                config = interp.compile(node)
            }

            flat = config.extract.flatten

            %w{puppet myhost}.each do |name|
                assert(flat.find{|o| o.name == name }, "Did not find #{name}")
            end
        }
        Puppet[:storeconfigs] = false
        Puppet::Resource::Catalog.cache_class =  catalog_cache_class
        Puppet::Node::Facts.cache_class = facts_cache_class
        Puppet::Node.cache_class = node_cache_class
    end
    else
        $stderr.puts "No ActiveRecord -- skipping collection tests"
    end

    def test_namespaces
        scope = mkscope

        assert_equal([""], scope.namespaces,
            "Started out with incorrect namespaces")
        assert_nothing_raised { scope.add_namespace("fun::test") }
        assert_equal(["fun::test"], scope.namespaces,
            "Did not add namespace correctly")
        assert_nothing_raised { scope.add_namespace("yay::test") }
        assert_equal(["fun::test", "yay::test"], scope.namespaces,
            "Did not add extra namespace correctly")
    end

    def test_find_hostclass_and_find_definition
        parser = mkparser

        # Make sure our scope calls the parser find_hostclass method with
        # the right namespaces
        scope = mkscope :parser => parser

        parser.singleton_class.send(:attr_accessor, :last)

        methods = [:find_hostclass, :find_definition]
        methods.each do |m|
            parser.meta_def(m) do |namespace, name|
                @checked ||= []
                @checked << [namespace, name]

                # Only return a value on the last call.
                if @last == namespace
                    ret = @checked.dup
                    @checked.clear
                    return ret
                else
                    return nil
                end
            end
        end

        test = proc do |should|
            parser.last = scope.namespaces[-1]
            methods.each do |method|
                result = scope.send(method, "testing")
                assert_equal(should, result,
                    "did not get correct value from %s with namespaces %s" %
                    [method, scope.namespaces.inspect])
            end
        end

        # Start with the empty namespace
        assert_nothing_raised { test.call([["", "testing"]]) }

        # Now add a namespace
        scope.add_namespace("a")
        assert_nothing_raised { test.call([["a", "testing"]]) }

        # And another
        scope.add_namespace("b")
        assert_nothing_raised { test.call([["a", "testing"], ["b", "testing"]]) }
    end

    # #629 - undef should be "" or :undef
    def test_lookupvar_with_undef
        scope = mkscope

        scope.setvar("testing", :undef)

        assert_equal(:undef, scope.lookupvar("testing", false),
            "undef was not returned as :undef when not string")

        assert_equal("", scope.lookupvar("testing", true),
            "undef was not returned as '' when string")
    end
end

