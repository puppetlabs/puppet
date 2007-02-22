#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
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
        scope = nil
        over = "over"

        scopes = []
        vars = []
        values = {}
        ovalues = []

        10.times { |index|
            # slap some recursion in there
            scope = mkscope(:parent => scope)
            scopes.push scope

            var = "var%s" % index
            value = rand(1000)
            ovalue = rand(1000)
            
            ovalues.push ovalue

            vars.push var
            values[var] = value

            # set the variable in the current scope
            assert_nothing_raised {
                scope.setvar(var,value)
            }

            # this should override previous values
            assert_nothing_raised {
                scope.setvar(over,ovalue)
            }

            assert_equal(value,scope.lookupvar(var))

            #puts "%s vars, %s scopes" % [vars.length,scopes.length]
            i = 0
            vars.zip(scopes) { |v,s|
                # this recurses all the way up the tree as necessary
                val = nil
                oval = nil

                # look up the values using the bottom scope
                assert_nothing_raised {
                    val = scope.lookupvar(v)
                    oval = scope.lookupvar(over)
                }

                # verify they're correct
                assert_equal(values[v],val)
                assert_equal(ovalue,oval)

                # verify that we get the most recent value
                assert_equal(ovalue,scope.lookupvar(over))

                # verify that they aren't available in upper scopes
                if parent = s.parent
                    val = nil
                    assert_nothing_raised {
                        val = parent.lookupvar(v)
                    }
                    assert_equal("", val, "Did not get empty string on missing var")

                    # and verify that the parent sees its correct value
                    assert_equal(ovalues[i - 1],parent.lookupvar(over))
                end
                i += 1
            }
        }
    end

    def test_declarative
        # set to declarative
        top = mkscope(:declarative => true)
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

    def test_notdeclarative
        # set to not declarative
        top = mkscope(:declarative => false)
        sub = mkscope(:parent => top)

        assert_nothing_raised {
            top.setvar("test","value")
        }
        assert_nothing_raised {
            top.setvar("test","other")
        }
        assert_nothing_raised {
            sub.setvar("test","later")
        }
        assert_nothing_raised {
            sub.setvar("test","yayness")
        }
    end

    def test_setdefaults
        interp, scope, source = mkclassframing

        # The setdefaults method doesn't really check what we're doing,
        # so we're just going to use fake defaults here.

        # First do a simple local lookup
        params = paramify(source, :one => "fun", :two => "shoe")
        origshould = {}
        params.each do |p| origshould[p.name] = p end
        assert_nothing_raised do
            scope.setdefaults(:file, params)
        end

        ret = nil
        assert_nothing_raised do
            ret = scope.lookupdefaults(:file)
        end

        assert_equal(origshould, ret)

        # Now create a subscope and add some more params.
        newscope = scope.newscope

        newparams = paramify(source, :one => "shun", :three => "free")
        assert_nothing_raised {
            newscope.setdefaults(:file, newparams)
        }

        # And make sure we get the appropriate ones back
        should = {}
        params.each do |p| should[p.name] = p end
        newparams.each do |p| should[p.name] = p end

        assert_nothing_raised do
            ret = newscope.lookupdefaults(:file)
        end

        assert_equal(should, ret)

        # Make sure we still only get the originals from the top scope
        assert_nothing_raised do
            ret = scope.lookupdefaults(:file)
        end

        assert_equal(origshould, ret)

        # Now create another scope and make sure we only get the top defaults
        otherscope = scope.newscope
        assert_equal(origshould, otherscope.lookupdefaults(:file))

        # And make sure none of the scopes has defaults for other types
        [scope, newscope, otherscope].each do |sc|
            assert_equal({}, sc.lookupdefaults(:exec))
        end
    end
    
    def test_strinterp
        scope = mkscope()

        assert_nothing_raised {
            scope.setvar("test","value")
        }
        val = nil
        assert_nothing_raised {
            val = scope.strinterp("string ${test}")
        }
        assert_equal("string value", val)

        assert_nothing_raised {
            val = scope.strinterp("string ${test} ${test} ${test}")
        }
        assert_equal("string value value value", val)

        assert_nothing_raised {
            val = scope.strinterp("string $test ${test} $test")
        }
        assert_equal("string value value value", val)

        assert_nothing_raised {
            val = scope.strinterp("string \\$test")
        }
        assert_equal("string $test", val)

        assert_nothing_raised {
            val = scope.strinterp("\\$test string")
        }
        assert_equal("$test string", val)
    end

    def test_setclass
        interp, scope, source = mkclassframing

        base = scope.findclass("base")
        assert(base, "Could not find base class")
        assert(! scope.setclass?(base), "Class incorrectly set")
        assert(! scope.classlist.include?("base"), "Class incorrectly in classlist")
        assert_nothing_raised do
            scope.setclass base
        end

        assert(scope.setclass?(base), "Class incorrectly unset")
        assert(scope.classlist.include?("base"), "Class not in classlist")

        # Make sure we can retrieve the scope.
        assert_equal(scope, scope.class_scope(base),
            "class scope was not set correctly")

        # Now try it with a normal string
        Puppet[:trace] = false
        assert_raise(Puppet::DevError) do
            scope.setclass "string"
        end

        assert(! scope.setclass?("string"), "string incorrectly set")

        # Set "" in the class list, and make sure it doesn't show up in the return
        top = scope.findclass("")
        assert(top, "Could not find top class")
        scope.setclass top

        assert(! scope.classlist.include?(""), "Class list included empty")
    end

    def test_validtags
        scope = mkscope()

        ["a class", "a.class"].each do |bad|
            assert_raise(Puppet::ParseError, "Incorrectly allowed %s" % bad.inspect) do
                scope.tag(bad)
            end
        end

        ["a-class", "a_class", "Class", "class", "yayNess"].each do |good|
            assert_nothing_raised("Incorrectly banned %s" % good.inspect) do
                scope.tag(good)
            end
        end

    end

    def test_tagfunction
        scope = mkscope()
        
        assert_nothing_raised {
            scope.function_tag(["yayness", "booness"])
        }

        assert(scope.tags.include?("yayness"), "tag 'yayness' did not get set")
        assert(scope.tags.include?("booness"), "tag 'booness' did not get set")

        # Now verify that the 'tagged' function works correctly
        assert(scope.function_tagged("yayness"),
            "tagged function incorrectly returned false")
        assert(scope.function_tagged("booness"),
            "tagged function incorrectly returned false")

        assert(! scope.function_tagged("funtest"),
            "tagged function incorrectly returned true")
    end

    def test_includefunction
        interp = mkinterp
        scope = mkscope :interp => interp

        myclass = interp.newclass "myclass"
        otherclass = interp.newclass "otherclass"

        function = Puppet::Parser::AST::Function.new(
            :name => "include",
            :ftype => :statement,
            :arguments => AST::ASTArray.new(
                :children => [nameobj("myclass"), nameobj("otherclass")]
            )
        )

        assert_nothing_raised do
            function.evaluate :scope => scope
        end

        [myclass, otherclass].each do |klass|
            assert(scope.setclass?(klass),
                "%s was not set" % klass.fqname)
        end
    end

    def test_definedfunction
        interp = mkinterp
        %w{one two}.each do |name|
            interp.newdefine name
        end

        scope = mkscope :interp => interp

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
    end

    # Verify scope context is handled correctly.
    def test_scopeinside
        scope = mkscope()

        one = :one
        two = :two

        # First just test the basic functionality.
        assert_nothing_raised {
            scope.inside :one do
                assert_equal(:one, scope.inside, "Context did not get set")
            end
            assert_nil(scope.inside, "Context did not revert")
        }

        # Now make sure error settings work.
        assert_raise(RuntimeError) {
            scope.inside :one do
                raise RuntimeError, "This is a failure, yo"
            end
        }
        assert_nil(scope.inside, "Context did not revert")

        # Now test it a bit deeper in.
        assert_nothing_raised {
            scope.inside :one do
                scope.inside :two do
                    assert_equal(:two, scope.inside, "Context did not get set")
                end
                assert_equal(:one, scope.inside, "Context did not get set")
            end
            assert_nil(scope.inside, "Context did not revert")
        }

        # And lastly, check errors deeper in
        assert_nothing_raised {
            scope.inside :one do
                begin
                    scope.inside :two do
                        raise "a failure"
                    end
                rescue
                end
                assert_equal(:one, scope.inside, "Context did not get set")
            end
            assert_nil(scope.inside, "Context did not revert")
        }

    end

    if defined? ActiveRecord
    # Verify that we recursively mark as exported the results of collectable
    # components.
    def test_exportedcomponents
        interp, scope, source = mkclassframing
        children = []

        args = AST::ASTArray.new(
            :file => tempfile(),
            :line => rand(100),
            :children => [nameobj("arg")]
        )

        # Create a top-level component
        interp.newdefine "one", :arguments => [%w{arg}],
            :code => AST::ASTArray.new(
                :children => [
                    resourcedef("file", "/tmp", {"owner" => varref("arg")})
                ]
            )

        # And a component that calls it
        interp.newdefine "two", :arguments => [%w{arg}],
            :code => AST::ASTArray.new(
                :children => [
                    resourcedef("one", "ptest", {"arg" => varref("arg")})
                ]
            )

        # And then a third component that calls the second
        interp.newdefine "three", :arguments => [%w{arg}],
            :code => AST::ASTArray.new(
                :children => [
                    resourcedef("two", "yay", {"arg" => varref("arg")})
                ]
            )

        # lastly, create an object that calls our third component
        obj = resourcedef("three", "boo", {"arg" => "parentfoo"})

        # And mark it as exported
        obj.exported = true

        obj.evaluate :scope => scope

        # And then evaluate it
        interp.evaliterate(scope)

        %w{file}.each do |type|
            objects = scope.lookupexported(type)

            assert(!objects.empty?, "Did not get an exported %s" % type)
        end
    end

    # Verify that we can both store and collect an object in the same
    # run, whether it's in the same scope as a collection or a different
    # scope.
    def test_storeandcollect
        Puppet[:storeconfigs] = true
        Puppet::Rails.init
        sleep 1
        children = []
        file = tempfile()
        File.open(file, "w") { |f|
            f.puts "
class yay {
    @@host { myhost: ip => \"192.168.0.2\" }
}
include yay
@@host { puppet: ip => \"192.168.0.3\" }
Host <<||>>"
        }

        interp = nil
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                :Manifest => file,
                :UseNodes => false,
                :ForkSave => false
            )
        }

        objects = nil
        # We run it twice because we want to make sure there's no conflict
        # if we pull it up from the database.
        2.times { |i|
            assert_nothing_raised {
                objects = interp.run("localhost", {"hostname" => "localhost"})
            }

            flat = objects.flatten

            %w{puppet myhost}.each do |name|
                assert(flat.find{|o| o.name == name }, "Did not find #{name}")
            end
        }
    end
    else
        $stderr.puts "No ActiveRecord -- skipping collection tests"
    end

    # Make sure tags behave appropriately.
    def test_tags
        interp, scope, source = mkclassframing

        # First make sure we can only set legal tags
        ["an invalid tag", "-anotherinvalid", "bad*tag"].each do |tag|
            assert_raise(Puppet::ParseError, "Tag #{tag} was considered valid") do
                scope.tag tag
            end
        end

        # Now make sure good tags make it through.
        tags = %w{good-tag yaytag GoodTag another_tag}
        tags.each do |tag|
            assert_nothing_raised("Tag #{tag} was considered invalid") do
                scope.tag tag
            end
        end

        # And make sure we get each of them.
        ptags = scope.tags
        tags.each do |tag|
            assert(ptags.include?(tag), "missing #{tag}")
        end


        # Now create a subscope and set some tags there
        newscope = scope.newscope(:type => 'subscope')

        # set some tags
        newscope.tag "onemore", "yaytag"

        # And make sure we get them plus our parent tags
        assert_equal((ptags + %w{onemore subscope}).sort, newscope.tags.sort)
    end

    # Make sure we successfully translate objects
    def test_translate
        interp, scope, source = mkclassframing

        # Create a define that we'll be using
        interp.newdefine("wrapper", :code => AST::ASTArray.new(:children => [
            resourcedef("file", varref("name"), "owner" => "root")
        ]))

        # Now create a resource that uses that define
        define = mkresource(:type => "wrapper", :title => "/tmp/testing",
            :scope => scope, :source => source, :params => :none)

        scope.setresource define

        # And a normal resource
        scope.setresource mkresource(:type => "file", :title => "/tmp/rahness",
            :scope => scope, :source => source,
            :params => {:owner => "root"})

        # Evaluate the the define thing.
        define.evaluate

        # Now the scope should have a resource and a subscope.  Translate the
        # whole thing.
        ret = nil
        assert_nothing_raised do
            ret = scope.translate
        end

        assert_instance_of(Puppet::TransBucket, ret)

        ret.each do |obj|
            assert(obj.is_a?(Puppet::TransBucket) || obj.is_a?(Puppet::TransObject),
                "Got a non-transportable object %s" % obj.class)
        end

        rahness = ret.find { |c| c.type == "file" and c.name == "/tmp/rahness" }
        assert(rahness, "Could not find top-level file")
        assert_equal("root", rahness["owner"])

        bucket = ret.find { |c| c.class == Puppet::TransBucket and c.name == "/tmp/testing" }
        assert(bucket, "Could not find define bucket")

        testing = bucket.find { |c| c.type == "file" and c.name == "/tmp/testing" }
        assert(testing, "Could not find define file")
        assert_equal("root", testing["owner"])

    end
end

# $Id$
