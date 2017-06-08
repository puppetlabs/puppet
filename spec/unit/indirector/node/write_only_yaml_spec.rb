#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node'
require 'puppet/indirector/node/write_only_yaml'

describe Puppet::Node::WriteOnlyYaml do
  it "should be deprecated" do
    Puppet.expects(:warn_once).with('deprecations', 'Puppet::Node::WriteOnlyYaml', 'Puppet::Node::WriteOnlyYaml is deprecated and will be removed in a future release of Puppet.')
    described_class.new
  end
end
