#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Node::Catalog do
    describe "when using the indirector" do
        after { Puppet::Node::Catalog.indirection.clear_cache }

        it "should be able to delegate to the :yaml terminus" do
            Puppet::Node::Catalog.indirection.stubs(:terminus_class).returns :yaml

            # Load now, before we stub the exists? method.
            Puppet::Node::Catalog.indirection.terminus(:yaml)

            file = File.join(Puppet[:yamldir], "catalog", "me.yaml")
            FileTest.expects(:exist?).with(file).returns false
            Puppet::Node::Catalog.find("me").should be_nil
        end

        it "should be able to delegate to the :compiler terminus" do
            Puppet::Node::Catalog.indirection.stubs(:terminus_class).returns :compiler

            # Load now, before we stub the exists? method.
            compiler = Puppet::Node::Catalog.indirection.terminus(:compiler)

            compiler.expects(:compile).with("me").returns nil

            Puppet::Node::Catalog.find("me").should be_nil
        end
    end
end
