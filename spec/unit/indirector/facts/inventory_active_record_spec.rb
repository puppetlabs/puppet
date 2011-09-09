#!/usr/bin/env rspec
require 'spec_helper'
begin
  require 'sqlite3'
rescue LoadError
end
require 'tempfile'
require 'puppet/rails'

describe "Puppet::Node::Facts::InventoryActiveRecord", :if => (Puppet.features.rails? and defined? SQLite3) do
  let(:terminus) { Puppet::Node::Facts::InventoryActiveRecord.new }

  before :all do
    require 'puppet/indirector/facts/inventory_active_record'
    @dbfile = Tempfile.new("testdb")
    @dbfile.close
  end

  after :all do
    Puppet::Node::Facts.indirection.reset_terminus_class
    @dbfile.unlink
  end

  before :each do
    Puppet::Node.indirection.reset_terminus_class
    Puppet::Node.indirection.cache_class = nil

    Puppet::Node::Facts.indirection.terminus_class = :inventory_active_record
    Puppet[:dbadapter]  = 'sqlite3'
    Puppet[:dblocation] = @dbfile.path
    Puppet[:railslog] = "/dev/null"
    Puppet::Rails.init
  end

  after :each do
    Puppet::Rails.teardown
    ActiveRecord::Base.remove_connection
  end

  describe "#save" do
    it "should use an existing node if possible" do
      node = Puppet::Rails::InventoryNode.new(:name => "foo", :timestamp => Time.now)
      node.save
      facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin")
      Puppet::Node::Facts.indirection.save(facts)

      Puppet::Rails::InventoryNode.count.should == 1
      Puppet::Rails::InventoryNode.first.should == node
    end

    it "should create a new node if one can't be found" do
      # This test isn't valid if there are nodes to begin with
      Puppet::Rails::InventoryNode.count.should == 0

      facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin")
      Puppet::Node::Facts.indirection.save(facts)

      Puppet::Rails::InventoryNode.count.should == 1
      Puppet::Rails::InventoryNode.first.name.should == "foo"
    end

    it "should save the facts" do
      facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin")
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
      Puppet::Indirector::Request.new(:facts, :search, nil, conditions)
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

