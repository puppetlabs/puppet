#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node'

describe "Puppet::Node::ActiveRecord", :if => Puppet.features.rails? && Puppet.features.sqlite? do
  include PuppetSpec::Files

  let(:nodename) { "mynode" }
  let(:fact_values) { {:afact => "a value"} }
  let(:facts) { Puppet::Node::Facts.new(nodename, fact_values) }
  let(:environment) { Puppet::Node::Environment.create(:myenv, []) }
  let(:request) { Puppet::Indirector::Request.new(:node, :find, nodename, nil, :environment => environment) }
  let(:node_indirection) { Puppet::Node::ActiveRecord.new }

  before do
    require 'puppet/indirector/node/active_record'
  end

  it "should issue a deprecation warning" do
    Puppet.expects(:deprecation_warning).with() { |msg| msg =~ /ActiveRecord-based storeconfigs and inventory are deprecated/ }
    Puppet[:statedir] = tmpdir('active_record_tmp')
    Puppet[:railslog] = '$statedir/rails.log'
    node_indirection
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

    node = Puppet::Node.new(nodename)
    db_instance.expects(:to_puppet).returns node

    Puppet[:statedir] = tmpdir('active_record_tmp')
    Puppet[:railslog] = '$statedir/rails.log'
    Puppet::Node::Facts.indirection.expects(:find).with(nodename, :environment => environment).returns(facts)

    node_indirection.find(request).parameters.should include(fact_values)
  end
end
