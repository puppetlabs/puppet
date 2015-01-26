#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/report'
require 'puppet/indirector/report/yaml'

describe Puppet::Transaction::Report::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Puppet::Transaction::Report::Yaml.superclass).to equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Puppet::Transaction::Report::Yaml.doc).not_to be_nil
  end

  it "should be registered with the report indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:report)
    expect(Puppet::Transaction::Report::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :yaml" do
    expect(Puppet::Transaction::Report::Yaml.name).to eq(:yaml)
  end

  it "should unconditionally save/load from the --lastrunreport setting" do
    expect(subject.path(:me)).to eq(Puppet[:lastrunreport])
  end
end
