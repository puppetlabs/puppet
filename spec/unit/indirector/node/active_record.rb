#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node'
require 'puppet/indirector/node/active_record'

describe Puppet::Node::ActiveRecord do
    confine "Missing Rails" => Puppet.features.rails?

    it "should be a subclass of the ActiveRecord terminus class" do
        Puppet::Node::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
    end

    it "should use Puppet::Rails::Host as its ActiveRecord model" do
        Puppet::Node::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
    end
end
