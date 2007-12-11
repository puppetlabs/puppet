#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/catalog'
require 'puppet/indirector/catalog/yaml'

describe Puppet::Node::Catalog::Yaml do
    it "should be a subclass of the Yaml terminus" do
        Puppet::Node::Catalog::Yaml.superclass.should equal(Puppet::Indirector::Yaml)
    end

    it "should have documentation" do
        Puppet::Node::Catalog::Yaml.doc.should_not be_nil
    end

    it "should be registered with the catalog store indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:catalog)
        Puppet::Node::Catalog::Yaml.indirection.should equal(indirection)
    end

    it "should have its name set to :yaml" do
        Puppet::Node::Catalog::Yaml.name.should == :yaml
    end
end
