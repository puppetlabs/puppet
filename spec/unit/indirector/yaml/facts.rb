#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/yaml/facts'

describe Puppet::Indirector::Yaml::Facts do
    it "should be a subclass of the Yaml terminus" do
        Puppet::Indirector::Yaml::Facts.superclass.should equal(Puppet::Indirector::Yaml)
    end


    it "should have documentation" do
        Puppet::Indirector::Yaml::Facts.doc.should_not be_nil
    end

    it "should be registered with the facts indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:facts)
        Puppet::Indirector::Yaml::Facts.indirection.should equal(indirection)
    end

    it "should have its name set to :facts" do
        Puppet::Indirector::Yaml::Facts.name.should == :facts
    end
end
