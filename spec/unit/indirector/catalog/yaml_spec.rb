#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/yaml'

describe Puppet::Resource::Catalog::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Puppet::Resource::Catalog::Yaml.superclass).to equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Puppet::Resource::Catalog::Yaml.doc).not_to be_nil
  end

  it "should be registered with the catalog store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:catalog)
    expect(Puppet::Resource::Catalog::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :yaml" do
    expect(Puppet::Resource::Catalog::Yaml.name).to eq(:yaml)
  end
end
