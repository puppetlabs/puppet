#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/node'

describe "Puppet::Node::ActiveRecord", :if => Puppet.features.rails? && Puppet.features.sqlite? do
  include PuppetSpec::Files

  before do
    require 'puppet/indirector/node/active_record'
  end

  it "should be a subclass of the ActiveRecord terminus class" do
    Puppet::Node::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
  end

  it "should use Puppet::Rails::Host as its ActiveRecord model" do
    Puppet::Node::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
  end

  it "should call fact_merge when a node is found" do
    db_instance = stub 'db_instance'
    Puppet::Node::ActiveRecord.ar_model.expects(:find_by_name).returns db_instance

    node = Puppet::Node.new("foo")
    db_instance.expects(:to_puppet).returns node

    Puppet[:statedir] = tmpdir('active_record_tmp')
    Puppet[:railslog] = '$statedir/rails.log'
    ar = Puppet::Node::ActiveRecord.new

    node.expects(:fact_merge)

    request = Puppet::Indirector::Request.new(:node, :find, "what.ever")
    ar.find(request)
  end
end
