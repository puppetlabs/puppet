#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2008-02-09.
#  Copyright (c) 2008. All rights reserved.

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'mocha'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

class TestASTNode < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
	AST = Puppet::Parser::AST

    def test_node
        scope = mkscope
        parser = scope.compile.parser

        # Define a base node
        basenode = parser.newnode "basenode", :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/base", "owner" => "root")
        ])

        # Now define a subnode
        nodes = parser.newnode ["mynode", "othernode"],
            :code => AST::ASTArray.new(:children => [
                resourcedef("file", "/tmp/mynode", "owner" => "root"),
                resourcedef("file", "/tmp/basenode", "owner" => "daemon")
        ])

        assert_instance_of(Array, nodes)

        # Make sure we can find them all.
        %w{mynode othernode}.each do |node|
            assert(parser.nodes[node], "Could not find %s" % node)
        end
        mynode = parser.nodes["mynode"]

        # Now try evaluating the node
        assert_nothing_raised do
            mynode.evaluate_code scope.resource
        end

        # Make sure that we can find each of the files
        myfile = scope.findresource "File[/tmp/mynode]"
        assert(myfile, "Could not find file from node")
        assert_equal("root", myfile[:owner])

        basefile = scope.findresource "File[/tmp/basenode]"
        assert(basefile, "Could not find file from base node")
        assert_equal("daemon", basefile[:owner])

        # Now make sure we can evaluate nodes with parents
        child = parser.newnode(%w{child}, :parent => "basenode").shift

        newscope = mkscope :parser => parser
        assert_nothing_raised do
            child.evaluate_code newscope.resource
        end

        assert(newscope.findresource("File[/tmp/base]"),
            "Could not find base resource")
    end
end
