#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/report'
require 'puppet/indirector/report/yaml'

describe Puppet::Transaction::Report::Yaml do
  it "should be a subclass of the Yaml terminus" do
    Puppet::Transaction::Report::Yaml.superclass.should equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    Puppet::Transaction::Report::Yaml.doc.should_not be_nil
  end

  it "should be registered with the report indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:report)
    Puppet::Transaction::Report::Yaml.indirection.should equal(indirection)
  end

  it "should have its name set to :yaml" do
    Puppet::Transaction::Report::Yaml.name.should == :yaml
  end

  it "should unconditionally save/load from the --lastrunreport setting" do
    subject.path(:me).should == Puppet[:lastrunreport]
  end
end
