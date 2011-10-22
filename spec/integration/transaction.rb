#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
    it "should not apply generated resources if the parent resource fails" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        catalog.add_resource resource

        child_resource = Puppet::Type.type(:file).new :path => "/foo/bar/baz", :backup => false

        resource.expects(:eval_generate).returns([child_resource])

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).raises "this is a failure"

        child_resource.expects(:evaluate).never

        transaction.evaluate
    end

    it "should not apply virtual resources" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        resource.virtual = true
        catalog.add_resource resource

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).never

        transaction.evaluate
    end

    it "should apply exported resources" do
        pending "failing before we started working on CVE-2011-3872"
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        resource.exported = true
        catalog.add_resource resource

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).never

        transaction.evaluate
    end

    it "should not apply virtual exported resources" do
        catalog = Puppet::Resource::Catalog.new
        resource = Puppet::Type.type(:file).new :path => "/foo/bar", :backup => false
        resource.exported = true
        resource.virtual = true
        catalog.add_resource resource

        transaction = Puppet::Transaction.new(catalog)

        resource.expects(:evaluate).never

        transaction.evaluate
    end

end
