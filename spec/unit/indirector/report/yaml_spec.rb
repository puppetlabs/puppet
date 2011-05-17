#!/usr/bin/env rspec
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

  it "should inconditionnally save/load from the --lastrunreport setting", :'fails_on_ruby_1.9.2' => true do
    indirection = stub 'indirection', :name => :my_yaml, :register_terminus_type => nil
    Puppet::Indirector::Indirection.stubs(:instance).with(:my_yaml).returns(indirection)
    store_class = Class.new(Puppet::Transaction::Report::Yaml) do
      def self.to_s
        "MyYaml::MyType"
      end
    end
    store = store_class.new

    store.path(:me).should == Puppet[:lastrunreport]
  end
end
