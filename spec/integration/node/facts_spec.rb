#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-4-8.
#  Copyright (c) 2008. All rights reserved.

require 'spec_helper'

describe Puppet::Node::Facts do
  describe "when using the indirector" do
    after(:each) { Puppet::Util::Cacher.expire }

    it "should expire any cached node instances when it is saved" do
      Puppet::Node::Facts.indirection.stubs(:terminus_class).returns :yaml

      Puppet::Node::Facts.indirection.terminus(:yaml).should equal(Puppet::Node::Facts.indirection.terminus(:yaml))
      terminus = Puppet::Node::Facts.indirection.terminus(:yaml)
      terminus.stubs :save

      Puppet::Node.indirection.expects(:expire).with("me")

      facts = Puppet::Node::Facts.new("me")
      Puppet::Node::Facts.indirection.save(facts)
    end

    it "should be able to delegate to the :yaml terminus" do
      Puppet::Node::Facts.indirection.stubs(:terminus_class).returns :yaml

      # Load now, before we stub the exists? method.
      terminus = Puppet::Node::Facts.indirection.terminus(:yaml)

      terminus.expects(:path).with("me").returns "/my/yaml/file"
      FileTest.expects(:exist?).with("/my/yaml/file").returns false

      Puppet::Node::Facts.indirection.find("me").should be_nil
    end

    it "should be able to delegate to the :facter terminus" do
      Puppet::Node::Facts.indirection.stubs(:terminus_class).returns :facter

      Facter.expects(:to_hash).returns "facter_hash"
      facts = Puppet::Node::Facts.new("me")
      Puppet::Node::Facts.expects(:new).with("me", "facter_hash").returns facts

      Puppet::Node::Facts.indirection.find("me").should equal(facts)
    end
  end
end
