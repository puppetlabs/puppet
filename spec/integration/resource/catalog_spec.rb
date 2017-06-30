#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Resource::Catalog do
  describe "when using the indirector" do
    before do
      # This is so the tests work w/out networking.
      Facter.stubs(:to_hash).returns({"hostname" => "foo.domain.com"})
      Facter.stubs(:value).returns("eh")
    end


    it "should be able to delegate to the :yaml terminus" do
      Puppet::Resource::Catalog.indirection.stubs(:terminus_class).returns :yaml

      # Load now, before we stub the exists? method.
      terminus = Puppet::Resource::Catalog.indirection.terminus(:yaml)
      terminus.expects(:path).with("me").returns "/my/yaml/file"

      Puppet::FileSystem.expects(:exist?).with("/my/yaml/file").returns false
      expect(Puppet::Resource::Catalog.indirection.find("me")).to be_nil
    end

    it "should be able to delegate to the :compiler terminus" do
      Puppet::Resource::Catalog.indirection.stubs(:terminus_class).returns :compiler

      # Load now, before we stub the exists? method.
      compiler = Puppet::Resource::Catalog.indirection.terminus(:compiler)

      node = mock 'node'
      node.stub_everything

      Puppet::Node.indirection.expects(:find).returns(node)
      compiler.expects(:compile).with(node, anything).returns nil

      expect(Puppet::Resource::Catalog.indirection.find("me")).to be_nil
    end

    it "should pass provided node information directly to the terminus" do
      terminus = mock 'terminus'

      Puppet::Resource::Catalog.indirection.stubs(:terminus).returns terminus

      node = mock 'node'
      terminus.stubs(:validate)
      terminus.expects(:find).with { |request| request.options[:use_node] == node }
      Puppet::Resource::Catalog.indirection.find("me", :use_node => node)
    end
  end
end
