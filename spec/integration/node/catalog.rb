#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-4-8.
#  Copyright (c) 2008. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Node::Catalog do
    describe "when using the indirector" do
        before do
            # This is so the tests work w/out networking.
            Facter.stubs(:to_hash).returns({"hostname" => "foo.domain.com"})
            Facter.stubs(:value).returns("eh")
        end

        after { Puppet::Node::Catalog.indirection.clear_cache }

        it "should be able to delegate to the :yaml terminus" do
            Puppet::Node::Catalog.indirection.stubs(:terminus_class).returns :yaml

            # Load now, before we stub the exists? method.
            terminus = Puppet::Node::Catalog.indirection.terminus(:yaml)
            terminus.expects(:path).with("me").returns "/my/yaml/file"

            FileTest.expects(:exist?).with("/my/yaml/file").returns false
            Puppet::Node::Catalog.find("me").should be_nil
        end

        it "should be able to delegate to the :compiler terminus" do
            Puppet::Node::Catalog.indirection.stubs(:terminus_class).returns :compiler

            # Load now, before we stub the exists? method.
            compiler = Puppet::Node::Catalog.indirection.terminus(:compiler)

            node = mock 'node'
            node.stub_everything

            Puppet::Node.expects(:find).returns(node)
            compiler.expects(:compile).with(node).returns nil

            Puppet::Node::Catalog.find("me").should be_nil
        end

        it "should pass provided node information directly to the terminus" do
            terminus = mock 'terminus'

            Puppet::Node::Catalog.indirection.stubs(:terminus).returns terminus

            node = mock 'node'
            terminus.expects(:find).with { |request| request.options[:use_node] == node }
            Puppet::Node::Catalog.find("me", :use_node => node)
        end
    end
end
