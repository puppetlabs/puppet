#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'test/unit'
require 'puppettest'

# so, what kind of things do we want to test?

# we don't need to test function, since we're confident in the
# library tests.  We do, however, need to test how things are actually
# working in the language.

# so really, we want to do things like test that our ast is correct
# and test whether we've got things in the right scopes

class TestScope < Test::Unit::TestCase
	include ParserTesting

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
            scope = Puppet::Parser::Scope.new(:parent => scope)
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
                    assert_raise(Puppet::ParseError) {
                        parent.lookupvar(v)
                    }

                    # and verify that the parent sees its correct value
                    assert_equal(ovalues[i - 1],parent.lookupvar(over))
                end
                i += 1
            }
        }
    end

    def test_declarative
        # set to declarative
        top = Puppet::Parser::Scope.new(:declarative => true)
        sub = Puppet::Parser::Scope.new(:parent => top)

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
        top = Puppet::Parser::Scope.new(:declarative => false)
        sub = Puppet::Parser::Scope.new(:parent => top)

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

    def test_defaults
        scope = nil
        over = "over"

        scopes = []
        vars = []
        values = {}
        ovalues = []

        defs = Hash.new { |hash,key|
            hash[key] = Hash.new(nil)
        }

        prevdefs = Hash.new { |hash,key|
            hash[key] = Hash.new(nil)
        }

        params = %w{a list of parameters that could be used for defaults}

        types = %w{a set of types that could be used to set defaults}

        10.times { |index|
            scope = Puppet::Parser::Scope.new(:parent => scope)
            scopes.push scope

            tmptypes = []

            # randomly create defaults for a random set of types
            tnum = rand(5)
            tnum.times { |t|
                # pick a type
                #Puppet.debug "Type length is %s" % types.length
                #s = rand(types.length)
                #Puppet.debug "Type num is %s" % s
                #type = types[s]
                #Puppet.debug "Type is %s" % s
                type = types[rand(types.length)]
                if tmptypes.include?(type)
                    Puppet.debug "Duplicate type %s" % type
                    redo
                else
                    tmptypes.push type
                end

                Puppet.debug "type is %s" % type

                d = {}

                # randomly assign some parameters
                num = rand(4)
                num.times { |n|
                    param = params[rand(params.length)]
                    if d.include?(param)
                        Puppet.debug "Duplicate param %s" % param
                        redo
                    else
                        d[param] = rand(1000)
                    end
                }

                # and then add a consistent type
                d["always"] = rand(1000)

                d.each { |var,val|
                    defs[type][var] = val
                }

                assert_nothing_raised {
                    scope.setdefaults(type,to_ary(d))
                }
                fdefs = nil
                assert_nothing_raised {
                    fdefs = scope.lookupdefaults(type)
                }

                # now, make sure that reassignment fails if we're
                # in declarative mode
                assert_raise(Puppet::ParseError) {
                    scope.setdefaults(type,[%w{always funtest}])
                }

                # assert that we have collected the same values
                assert_equal(defs[type],fdefs)

                # now assert that our parent still finds the same defaults
                # it got last time
                if parent = scope.parent
                    unless prevdefs[type].nil?
                        assert_equal(prevdefs[type],parent.lookupdefaults(type))
                    end
                end
                d.each { |var,val|
                    prevdefs[type][var] = val
                }
            }
        }
    end
    
    def test_strinterp
        scope = Puppet::Parser::Scope.new()

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
    end

    # Test some of the host manipulations
    def test_hostlookup
        top = Puppet::Parser::Scope.new()

        # Create a deep scope tree, so that we know we're doing a deeply recursive
        # search.
        mid1 = Puppet::Parser::Scope.new(:parent => top)
        mid2 = Puppet::Parser::Scope.new(:parent => mid1)
        mid3 = Puppet::Parser::Scope.new(:parent => mid2)
        child1 = Puppet::Parser::Scope.new(:parent => mid3)
        mida = Puppet::Parser::Scope.new(:parent => top)
        midb = Puppet::Parser::Scope.new(:parent => mida)
        midc = Puppet::Parser::Scope.new(:parent => midb)
        child2 = Puppet::Parser::Scope.new(:parent => midc)

        # verify we can set a host
        assert_nothing_raised("Could not create host") {
            child1.setnode("testing", AST::Node.new(
                :name => "testing",
                :code => :notused
                )
            )
        }

        # Verify we cannot redefine it
        assert_raise(Puppet::ParseError, "Duplicate host creation succeeded") {
            child2.setnode("testing", AST::Node.new(
                :name => "testing",
                :code => :notused
                )
            )
        }

        # Now verify we can find the host again
        host = nil
        assert_nothing_raised("Host lookup failed") {
            hash = top.node("testing")
            host = hash[:node]
        }

        assert(host, "Could not find host")
        assert(host.code == :notused, "Host is not what we stored")
    end

    # Verify that two statements about a file within the same scope tree
    # will cause a conflict.
    def test_noconflicts
        filename = tempfile()
        children = []

        # create the parent class
        children << classobj("one", :code => AST::ASTArray.new(
            :children => [
                fileobj(filename, "owner" => "root")
            ]
        ))

        # now create a child class with differ values
        children << classobj("two",
            :code => AST::ASTArray.new(
                :children => [
                    fileobj(filename, "owner" => "bin")
                ]
        ))

        # Now call the child class
        assert_nothing_raised("Could not add AST nodes for calling") {
            children << AST::ObjectDef.new(
                :type => nameobj("two"),
                :name => nameobj("yayness"),
                :params => astarray()
            ) << AST::ObjectDef.new(
                :type => nameobj("one"),
                :name => nameobj("yayness"),
                :params => astarray()
            )
        }

        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        objects = nil
        scope = nil

        # Here's where we should encounter the failure.  It should find that
        # it has already created an object with that name, and this should result
        # in some pukey-pukeyness.
        assert_raise(Puppet::ParseError) {
            scope = Puppet::Parser::Scope.new()
            objects = scope.evaluate(:ast => top)
        }
    end

    # Verify that we override statements that we find within our scope
    def test_suboverrides
        filename = tempfile()
        children = []

        # create the parent class
        children << classobj("parent", :code => AST::ASTArray.new(
            :children => [
                fileobj(filename, "owner" => "root")
            ]
        ))

        # now create a child class with differ values
        children << classobj("child", :parentclass => nameobj("parent"),
            :code => AST::ASTArray.new(
                :children => [
                    fileobj(filename, "owner" => "bin")
                ]
        ))

        # Now call the child class
        assert_nothing_raised("Could not add AST nodes for calling") {
            children << AST::ObjectDef.new(
                :type => nameobj("child"),
                :name => nameobj("yayness"),
                :params => astarray()
            )
        }

        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        objects = nil
        scope = nil
        assert_nothing_raised("Could not evaluate") {
            scope = Puppet::Parser::Scope.new()
            scope.name =  "topscope"
            scope.type =  "topscope"
            objects = scope.evaluate(:ast => top)
        }

        assert_equal(1, objects.length, "Returned too many objects: %s" %
            objects.inspect)
        assert_equal(1, objects[0].length, "Returned too many objects: %s" %
            objects[0].inspect)
        assert_nothing_raised {
            file = objects[0][0]

            assert_equal("bin", file["owner"], "Value did not override correctly")
        }
    end

    def test_classscopes
    end
end
