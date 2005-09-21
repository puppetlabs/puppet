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

class TestAST < TestPuppet
    AST = Puppet::Parser::AST

    def astarray
        AST::ASTArray.new(
            :children => []
        )
    end

    def fileobj(path, hash = {"owner" => "root"})
        assert_nothing_raised("Could not create file %s" % path) {
            return AST::ObjectDef.new(
                :name => stringobj(path),
                :type => nameobj("file"),
                :params => objectinst(hash)
            )
        }
    end

    def nameobj(name)
        assert_nothing_raised("Could not create name %s" % name) {
            return AST::Name.new(
                :value => name
            )
        }
    end

    def objectinst(hash)
        assert_nothing_raised("Could not create object instance") {
            params = hash.collect { |param, value|
                objectparam(param, value)
            }
            return AST::ObjectInst.new(
                :children => params
            )
        }
    end

    def objectparam(param, value)
        assert_nothing_raised("Could not create param %s" % param) {
            return AST::ObjectParam.new(
                :param => nameobj(param),
                :value => stringobj(value)
            )
        }
    end

    def stringobj(value)
        AST::String.new(:value => value)
    end

    def varobj(name, value)
        assert_nothing_raised("Could not create %s code" % name) {
            return AST::VarDef.new(
                :name => nameobj(name),
                :value => stringobj(value)
            )
        }
    end

    # Test that classes behave like singletons
    def test_classsingleton
        parent = child1 = child2 = nil
        children = []

        # create the parent class
        assert_nothing_raised("Could not create parent object") {
            children << AST::ClassDef.new(
                :name => nameobj("parent"),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("parentvar", "parentval"),
                        fileobj("/etc")
                    ]
                )
            )
        }

        # Create child class one
        assert_nothing_raised("Could not create child1 object") {
            children << AST::ClassDef.new(
                :name => nameobj("child1"),
                :parentclass => nameobj("parent"),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("child1var", "child1val"),
                        fileobj("/tmp")
                    ]
                )
            )
        }

        # Create child class two
        assert_nothing_raised("Could not create child2 object") {
            children << AST::ClassDef.new(
                :name => nameobj("child2"),
                :parentclass => nameobj("parent"),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("child2var", "child2val"),
                        fileobj("/var")
                    ]
                )
            )
        }

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
            child.lookupobject("/etc", "file")
            #child.lookupobject("file", "/etc")
        }.length, "Found incorrect number of '/etc' objects")
    end

    # Test that 'setobject' collects all of an object's parameters and stores
    # them in one TransObject, rather than many.  This is probably a bad idea.
    def test_setobject
        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => [
                    fileobj("/etc", "owner" => "root"),
                    fileobj("/etc", "group" => "root")
                ]
            )
        }
        scope = nil
        assert_nothing_raised("Could not evaluate") {
            scope = Puppet::Parser::Scope.new()
            objects = top.evaluate(scope)
        }

        obj = nil
        assert_nothing_raised("Could not retrieve file object") {
            obj = scope.lookupobject("file", "/etc")
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
        assert_nothing_raised("Could not create parent object") {
            children << AST::CompDef.new(
                :name => nameobj("parent"),
                :args => AST::ASTArray.new(:children => []),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("parentvar", "parentval"),
                        fileobj("/etc")
                    ]
                )
            )
        }

        # Create child class one
        assert_nothing_raised("Could not create child1 object") {
            children << AST::ClassDef.new(
                :name => nameobj("child1"),
                :parentclass => nameobj("parent"),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("child1var", "child1val"),
                        fileobj("/tmp")
                    ]
                )
            )
        }

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
        assert_nothing_raised("Could not create parent object") {
            children << AST::ClassDef.new(
                :name => nameobj("parent"),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("parentvar", "parentval"),
                        fileobj("/etc")
                    ]
                )
            )
        }

        # Create child class one
        assert_nothing_raised("Could not create child1 object") {
            children << AST::ClassDef.new(
                :name => nameobj("child1"),
                :parentclass => nameobj("parent"),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("child1var", "child1val"),
                        fileobj("/tmp")
                    ]
                )
            )
        }

        # Now call the two classes
        assert_nothing_raised("Could not add AST nodes for calling") {
            children << AST::ObjectDef.new(
                :type => nameobj("child1"),
                :name => nameobj("yayness"),
                :params => astarray()
            )
        }

        # create the node
        node = nil
        assert_nothing_raised("Could not create parent object") {
            node = AST::NodeDef.new(
                :names => nameobj("node"),
                :code => AST::ASTArray.new(
                    :children => children
                )
            )
        }

        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => [node]
            )
        }

        scope = nil
        assert_nothing_raised("Could not evaluate node") {
            scope = Puppet::Parser::Scope.new()
            objects = top.evaluate(scope)
        }

        assert(scope.topscope?, "Scope is not top scope")
        assert(! scope.nodescope?, "Scope is mistakenly node scope")
        assert(! scope.lookupclass("parent"), "Found parent class in top scope")

        nodescope = scope.find { |child| child.nodescope?  }

        assert(nodescope, "Could not find nodescope")

        assert(nodescope.lookupclass("parent"),
            "Could not find parent class in node scope")
    end
end
