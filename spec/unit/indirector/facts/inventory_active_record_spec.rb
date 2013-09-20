#! /usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Node::Facts::InventoryActiveRecord", :if => can_use_scratch_database? do
  include PuppetSpec::Files

  let(:terminus) { Puppet::Node::Facts::InventoryActiveRecord.new }

  before :each do
    require 'puppet/indirector/facts/inventory_active_record'
    Puppet::Node::Facts.indirection.terminus_class = :inventory_active_record
    setup_scratch_database
  end

  after :each do
    Puppet::Rails.teardown
  end

  context "under Ruby 1.x", :if => (RUBY_VERSION[0] == '1' and can_use_scratch_database?) do
    describe "#initialize" do
      it "should issue a deprecation warning" do
        Puppet.expects(:deprecation_warning).with() { |msg| msg =~ /ActiveRecord-based storeconfigs and inventory are deprecated/ }
        terminus
      end
    end

    describe "#save" do
      let(:node) {
        Puppet::Rails::InventoryNode.new(:name => "foo", :timestamp => Time.now)
      }

      let(:facts) {
        Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin")
      }

      it "should retry on ActiveRecord error" do
        Puppet::Rails::InventoryNode.expects(:create).twice.raises(ActiveRecord::StatementInvalid).returns node

        Puppet::Node::Facts.indirection.save(facts)
      end

      it "should use an existing node if possible" do
        node.save
        Puppet::Node::Facts.indirection.save(facts)

        Puppet::Rails::InventoryNode.count.should == 1
        Puppet::Rails::InventoryNode.first.should == node
      end

      it "should create a new node if one can't be found" do
        # This test isn't valid if there are nodes to begin with
        Puppet::Rails::InventoryNode.count.should == 0

        Puppet::Node::Facts.indirection.save(facts)

        Puppet::Rails::InventoryNode.count.should == 1
        Puppet::Rails::InventoryNode.first.name.should == "foo"
      end

      it "should save the facts" do
        Puppet::Node::Facts.indirection.save(facts)

        Puppet::Rails::InventoryFact.all.map{|f| [f.name,f.value]}.should =~ [["uptime_days","60"],["kernel","Darwin"]]
      end

      it "should remove the previous facts for an existing node" do
        facts = Puppet::Node::Facts.new("foo", "uptime_days" => "30", "kernel" => "Darwin")
        Puppet::Node::Facts.indirection.save(facts)
        bar_facts = Puppet::Node::Facts.new("bar", "uptime_days" => "35", "kernel" => "Linux")
        foo_facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "is_virtual" => "false")
        Puppet::Node::Facts.indirection.save(bar_facts)
        Puppet::Node::Facts.indirection.save(foo_facts)

        Puppet::Node::Facts.indirection.find("bar").should == bar_facts
        Puppet::Node::Facts.indirection.find("foo").should == foo_facts
        Puppet::Rails::InventoryFact.all.map{|f| [f.name,f.value]}.should_not include(["uptime_days", "30"], ["kernel", "Darwin"])
      end
    end

    describe "#find" do
      before do
        @foo_facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin")
        @bar_facts = Puppet::Node::Facts.new("bar", "uptime_days" => "30", "kernel" => "Linux")
        Puppet::Node::Facts.indirection.save(@foo_facts)
        Puppet::Node::Facts.indirection.save(@bar_facts)
      end

      it "should identify facts by node name" do
        Puppet::Node::Facts.indirection.find("foo").should == @foo_facts
      end

      it "should return nil if no node instance can be found" do
        Puppet::Node::Facts.indirection.find("non-existent node").should == nil
      end
    end

    describe "#search" do
      def search_request(conditions)
        Puppet::Indirector::Request.new(:facts, :search, nil, nil, conditions)
      end

      before :each do
        @now = Time.now
        @foo = Puppet::Node::Facts.new("foo", "fact1" => "value1", "fact2" => "value2", "uptime_days" => "30")
        @bar = Puppet::Node::Facts.new("bar", "fact1" => "value1", "uptime_days" => "60")
        @baz = Puppet::Node::Facts.new("baz", "fact1" => "value2", "fact2" => "value1", "uptime_days" => "90")
        @bat = Puppet::Node::Facts.new("bat")
        @foo.timestamp = @now - 3600*1
        @bar.timestamp = @now - 3600*3
        @baz.timestamp = @now - 3600*5
        @bat.timestamp = @now - 3600*7
        [@foo, @bar, @baz, @bat].each {|facts| Puppet::Node::Facts.indirection.save(facts)}
      end

      it "should return node names that match 'equal' constraints" do
        request = search_request('facts.fact1.eq' => 'value1',
                                 'facts.fact2.eq' => 'value2')
        terminus.search(request).should == ["foo"]
      end

      it "should return node names that match 'not equal' constraints" do
        request = search_request('facts.fact1.ne' => 'value2')
        terminus.search(request).should == ["bar","foo"]
      end

      it "should return node names that match strict inequality constraints" do
        request = search_request('facts.uptime_days.gt' => '20',
                                 'facts.uptime_days.lt' => '70')
        terminus.search(request).should == ["bar","foo"]
      end

      it "should return node names that match non-strict inequality constraints" do
        request = search_request('facts.uptime_days.ge' => '30',
                                 'facts.uptime_days.le' => '60')
        terminus.search(request).should == ["bar","foo"]
      end

      it "should return node names whose facts are within a given timeframe" do
        request = search_request('meta.timestamp.ge' => @now - 3600*5,
                                 'meta.timestamp.le' => @now - 3600*1)
        terminus.search(request).should == ["bar","baz","foo"]
      end

      it "should return node names whose facts are from a specific time" do
        request = search_request('meta.timestamp.eq' => @now - 3600*3)
        terminus.search(request).should == ["bar"]
      end

      it "should return node names whose facts are not from a specific time" do
        request = search_request('meta.timestamp.ne' => @now - 3600*1)
        terminus.search(request).should == ["bar","bat","baz"]
      end

      it "should perform strict searches on nodes by timestamp" do
        request = search_request('meta.timestamp.gt' => @now - 3600*5,
                                 'meta.timestamp.lt' => @now - 3600*1)
        terminus.search(request).should == ["bar"]
      end

      it "should search nodes based on both facts and timestamp values" do
        request = search_request('facts.uptime_days.gt' => '45',
                                 'meta.timestamp.lt'    => @now - 3600*4)
        terminus.search(request).should == ["baz"]
      end
    end
  end

  context "under Ruby 2.x", :if => (RUBY_VERSION[0] == '2' and can_use_scratch_database?) do
    describe "#initialize" do
      it "should raise error under Ruby 2" do
        lambda { terminus }.should raise_error(Puppet::Error, /Ruby 2/)
      end
    end
  end
end
