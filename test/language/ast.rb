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

class TestAST < Test::Unit::TestCase
	include ParserTesting

    # Test that classes behave like singletons
    def test_classsingleton
        parent = child1 = child2 = nil
        children = []

        # create the parent class
        children << classobj("parent")

        # Create child class one
        children << classobj("child1", :parentclass => nameobj("parent"))

        # Create child class two
        children << classobj("child2", :parentclass => nameobj("parent"))

        # Now call the two classes
        assert_nothing_raised("Could not add AST nodes for calling") {
            children << AST::ObjectDef.new(
                :type => nameobj("child1"),
                :name => nameobj("yayness"),
                :params => astarray()
            )
            children << AST::ObjectDef.new(
                :type => nameobj("child2"),
                :name => nameobj("booness"),
                :params => astarray()
            )
        }

        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        scope = nil
        assert_nothing_raised("Could not evaluate") {
            scope = Puppet::Parser::Scope.new()
            objects = top.evaluate(scope)
        }

        assert_equal(1, scope.find_all { |child|
            child.lookupobject("/parent", "file")
        }.length, "Found incorrect number of '/parent' objects")
    end

    # Test that 'setobject' collects all of an object's parameters and stores
    # them in one TransObject, rather than many.  This is probably a bad idea.
    def test_setobject
        top = nil
        children = [
            fileobj("/etc", "owner" => "root"),
            fileobj("/etc", "group" => "root")
        ]
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        scope = Puppet::Parser::Scope.new()
        assert_nothing_raised("Could not evaluate") {
            top.evaluate(scope)
        }

        obj = nil
        assert_nothing_raised("Could not retrieve file object") {
            obj = scope.lookupobject("/etc", "file")
        }

        assert(obj, "could not retrieve file object")

        %w{owner group}.each { |param|
            assert(obj.include?(param), "Object did not include %s" % param)
        }

    end

    # Verify that objects can only have parents of the same type.
    def test_validparent
        parent = child1 = nil
        children = []

        # create the parent class
        children << compobj("parent", :args => AST::ASTArray.new(:children => []))

        # Create child class one
        children << classobj("child1", :parentclass => nameobj("parent"))

        # Now call the two classes
        assert_nothing_raised("Could not add AST nodes for calling") {
            children << AST::ObjectDef.new(
                :type => nameobj("child1"),
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

        scope = nil
        assert_raise(Puppet::ParseError, "Invalid parent type was allowed") {
            scope = Puppet::Parser::Scope.new()
            objects = top.evaluate(scope)
        }
    end

    # Verify that classes are correctly defined in node scopes.
    def test_nodeclasslookup
        parent = child1 = nil
        children = []

        # create the parent class
        children << classobj("parent")

        # Create child class one
        children << classobj("child1", :parentclass => nameobj("parent"))

        # Now call the two classes
        assert_nothing_raised("Could not add AST nodes for calling") {
            children << AST::ObjectDef.new(
                :type => nameobj("child1"),
                :name => nameobj("yayness"),
                :params => astarray()
            )
        }

        # create the node
        nodename = "mynodename"
        node = nil
        assert_nothing_raised("Could not create parent object") {
            node = AST::NodeDef.new(
                :names => nameobj(nodename),
                :code => AST::ASTArray.new(
                    :children => children
                )
            )
        }

        # Create the wrapper object
        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => [node]
            )
        }

        # Evaluate the parse tree
        scope = nil
        assert_nothing_raised("Could not evaluate node") {
            scope = Puppet::Parser::Scope.new()
            top.evaluate(scope)
        }

        # Verify that, well, nothing really happened, and especially verify
        # that the top scope is not a node scope
        assert(scope.topscope?, "Scope is not top scope")
        assert(! scope.nodescope?, "Scope is mistakenly node scope")
        assert(! scope.lookupclass("parent"), "Found parent class in top scope")

        # verify we can find our node
        assert(scope.node(nodename), "Could not find node")

        # And verify that we can evaluate it okay
        objects = nil
        assert_nothing_raised("Could not retrieve node definition") {
            objects = scope.evalnode([nodename], {})
        }
        assert(objects, "Could not retrieve node definition")

        # Because node scopes are temporary (i.e., they get destroyed after the node's
        # config is returned) we should not be able to find the node scope.
        nodescope = nil
        assert_nothing_raised {
            nodescope = scope.find { |child|
                child.nodescope?
            }
        }

        assert_nil(nodescope, "Found nodescope")

        # And now verify again that the top scope cannot find the node's definition
        # of the parent class
        assert(! scope.lookupclass("parent"), "Found parent class in top scope")

        # Verify that we can evaluate the node twice
        assert_nothing_raised("Could not retrieve node definition") {
            scope.evalnode([nodename], {})
        }
    end

    # Test that you can look a host up using multiple names, e.g., an FQDN and
    # a short name
    def test_multiplenodenames
        children = []

        # create a short-name node
        shortname = "mynodename"
        children << nodeobj(shortname)

        # And a long-name node
        longname = "node.domain.com"
        children << nodeobj(longname)

        # Create the wrapper object
        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        # Evaluate the parse tree
        scope = nil
        assert_nothing_raised("Could not evaluate node") {
            scope = Puppet::Parser::Scope.new()
            top.evaluate(scope)
        }

        # Verify we can find the node via a search list
        objects = nil
        assert_nothing_raised("Could not retrieve short node definition") {
            objects = scope.evalnode(["%s.domain.com" % shortname, shortname], {})
        }
        assert(objects, "Could not retrieve short node definition")

        # and then look for the long name
        assert_nothing_raised("Could not retrieve long node definition") {
            objects = scope.evalnode([longname.sub(/\..+/, ''), longname], {})
        }
        assert(objects, "Could not retrieve long node definition")
    end

    # Test that a node gets the entire configuration except for work meant for
    # another node
    def test_fullconfigwithnodes
        children = []

        children << fileobj("/testing")

        # create a short-name node
        name = "mynodename"
        children << nodeobj(name)

        # Create the wrapper object
        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        # Evaluate the parse tree
        scope = nil
        assert_nothing_raised("Could not evaluate node") {
            scope = Puppet::Parser::Scope.new()
            top.evaluate(scope)
        }

        # Verify we can find the node via a search list
        objects = nil
        assert_nothing_raised("Could not retrieve short node definition") {
            objects = scope.evalnode([name], {})
        }
        assert(objects, "Could not retrieve short node definition")

        # And now verify that we got both the top and node objects
        assert_nothing_raised("Could not find top-declared object") {
            assert_equal("/testing", objects[0][:name])
        }

        assert_nothing_raised("Could not find node-declared object") {
            assert_equal("/%s" % name, objects[1][0][:name])
        }
    end

    # Test that we can 'include' variables, not just normal strings.
    def test_includevars
        children = []

        # Create our class for testin
        klassname = "include"
        children << classobj(klassname)

        # Then add our variable assignment
        children << varobj("klassvar", klassname)

        # And finally add our calling of the variable
        children << AST::ObjectDef.new(
            :type => AST::Variable.new(:value => "klassvar"),
            :params => astarray
        )

        # And then create our top object
        top = AST::ASTArray.new(
            :children => children
        )

        # Evaluate the parse tree
        scope = nil
        assert_nothing_raised("Could not evaluate node") {
            scope = Puppet::Parser::Scope.new()
            top.evaluate(scope)
        }

        # Verify we can find the node via a search list
        objects = nil
        assert_nothing_raised("Could not retrieve objects") {
            objects = scope.to_trans
        }
        assert(objects, "Could not retrieve objects")

        assert_nothing_raised("Could not find top-declared object") {
            assert_equal("/%s" % klassname, objects[0][0][:name])
        }
    end

    # Test that node inheritance works correctly
    def test_znodeinheritance
        children = []

        # create the base node
        name = "basenode"
        children << nodeobj(name)

        # and the sub node
        name = "subnode"
        children << AST::NodeDef.new(
            :names => nameobj(name),
            :parentclass => nameobj("basenode"),
            :code => AST::ASTArray.new(
                :children => [
                    varobj("%svar" % name, "%svalue" % name),
                    fileobj("/%s" % name)
                ]
            )
        )
        #subnode = nodeobj(name)
        #subnode.parentclass = "basenode"

        #children << subnode

        # and the top object
        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        # Evaluate the parse tree
        scope = nil
        assert_nothing_raised("Could not evaluate node") {
            scope = Puppet::Parser::Scope.new()
            top.evaluate(scope)
        }

        # Verify we can find the node via a search list
        objects = nil
        assert_nothing_raised("Could not retrieve node definition") {
            objects = scope.evalnode([name], {})
        }
        assert(objects, "Could not retrieve node definition")

        assert_nothing_raised {
            inner = objects[0]

            # And now verify that we got the subnode file
            assert_nothing_raised("Could not find basenode file") {
                base = inner[0]
                assert_equal("/basenode", base[:name])
            }

            # and the parent node file
            assert_nothing_raised("Could not find subnode file") {
                sub = inner[1]
                assert_equal("/subnode", sub[:name])
            }

            inner.each { |obj|
                %w{basenode subnode}.each { |tag|
                    assert(obj.tags.include?(tag),
                        "%s did not include %s tag" % [obj[:name], tag]
                    )
                }
            }
        }
    end
end
