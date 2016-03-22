#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/yaml'

describe Puppet::Resource::Catalog::Yaml do
  it "should be a subclass of the Yaml terminus" do
    Puppet::Resource::Catalog::Yaml.superclass.should equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    Puppet::Resource::Catalog::Yaml.doc.should_not be_nil
  end

  it "should be registered with the catalog store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:catalog)
    Puppet::Resource::Catalog::Yaml.indirection.should equal(indirection)
  end

  it "should have its name set to :yaml" do
    Puppet::Resource::Catalog::Yaml.name.should == :yaml
  end
end
