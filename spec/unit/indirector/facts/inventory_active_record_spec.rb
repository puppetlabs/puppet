#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'sqlite3' rescue nil
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
    Puppet::Node::Facts.terminus_class = :inventory_active_record
    Puppet[:dbadapter]  = 'sqlite3'
    Puppet[:dblocation] = @dbfile.path
    Puppet[:railslog] = "/dev/null"
    Puppet::Rails.init
  end

  after :each do
    Puppet::Rails.teardown
  end

  describe "#save" do
    it "should use an existing host if possible" do
      host = Puppet::Rails::InventoryHost.new(:name => "foo", :timestamp => Time.now)
      host.save
      Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin").save

      Puppet::Rails::InventoryHost.count.should == 1
      Puppet::Rails::InventoryHost.first.should == host
    end

    it "should create a new host if one can't be found" do
      # This test isn't valid if there are hosts to begin with
      Puppet::Rails::InventoryHost.count.should == 0

      Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin").save

      Puppet::Rails::InventoryHost.count.should == 1
      Puppet::Rails::InventoryHost.first.name.should == "foo"
    end

    it "should save the facts" do
      Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin").save

      Puppet::Rails::InventoryFact.all.map{|f| [f.name,f.value]}.should =~ [["uptime_days","60"],["kernel","Darwin"]]
    end

    it "should remove the previous facts for an existing host" do
      Puppet::Node::Facts.new("foo", "uptime_days" => "30", "kernel" => "Darwin").save
      bar_facts = Puppet::Node::Facts.new("bar", "uptime_days" => "35", "kernel" => "Linux")
      foo_facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "is_virtual" => "false")
      bar_facts.save
      foo_facts.save

      Puppet::Node::Facts.find("bar").should == bar_facts
      Puppet::Node::Facts.find("foo").should == foo_facts
      Puppet::Rails::InventoryFact.all.map{|f| [f.name,f.value]}.should_not include(["uptime_days", "30"], ["kernel", "Darwin"])
    end

    it "should not replace the node's facts if something goes wrong" do
    end
  end

  describe "#find" do
    before do
      @foo_facts = Puppet::Node::Facts.new("foo", "uptime_days" => "60", "kernel" => "Darwin")
      @bar_facts = Puppet::Node::Facts.new("bar", "uptime_days" => "30", "kernel" => "Linux")
      @foo_facts.save
      @bar_facts.save
    end

    it "should identify facts by host name" do
      Puppet::Node::Facts.find("foo").should == @foo_facts
    end

    it "should return nil if no host instance can be found" do
      Puppet::Node::Facts.find("non-existent host").should == nil
    end

    it "should convert all single-member arrays into non-arrays" do
      Puppet::Node::Facts.new("array", "fact1" => ["value1"]).save

      Puppet::Node::Facts.find("array").values["fact1"].should == "value1"
    end
  end

  describe "#search" do

    it "should return node names that match 'equal' constraints" do
      Puppet::Node::Facts.new("foo", "fact1" => "value1", "fact2" => "value2", "fact3" => "value3").save
      Puppet::Node::Facts.new("bar", "fact1" => "value2").save
      Puppet::Node::Facts.new("baz", "fact1" => "value1", "fact2" => "value1", "fact3" => "value1").save

      request = Puppet::Indirector::Request.new(:facts, :search, nil,
                                                {'facts.fact1.eq' => 'value1',
                                                 'facts.fact2.eq' => 'value2',
                                                 'facts.fact3.eq' => 'value3'})
      terminus.search(request).should =~ ["foo"]
    end

    it "should return node names that match 'not equal' constraints" do
      Puppet::Node::Facts.new("foo", "fact1" => "value1", "fact2" => "value2", "fact3" => "value3").save
      Puppet::Node::Facts.new("bar", "fact1" => "value2").save
      Puppet::Node::Facts.new("baz", "fact1" => "value1", "fact2" => "value1", "fact3" => "value1").save
      Puppet::Node::Facts.new("bang", "fact1" => "value1", "fact2" => "value2", "fact3" => "value1").save

      request = Puppet::Indirector::Request.new(:facts, :search, nil,
                                                {'facts.fact1.ne' => 'value3',
                                                 'facts.fact2.ne' => 'value1',
                                                 'facts.fact3.ne' => 'value2'})
      terminus.search(request).should =~ ["foo","bang"]
    end

    it "should return node names that match strict inequality constraints" do
      Puppet::Node::Facts.new("foo", "uptime_days" => "30").save
      Puppet::Node::Facts.new("bar", "uptime_days" => "60").save
      Puppet::Node::Facts.new("baz", "uptime_days" => "90").save

      request = Puppet::Indirector::Request.new(:facts, :search, nil,
                                                {'facts.uptime_days.gt' => '20',
                                                 'facts.uptime_days.lt' => '70'})

      terminus.search(request).should =~ ["foo","bar"]
    end

    it "should return node names that match non-strict inequality constraints" do
      Puppet::Node::Facts.new("foo", "uptime_days" => "30").save
      Puppet::Node::Facts.new("bar", "uptime_days" => "60").save
      Puppet::Node::Facts.new("baz", "uptime_days" => "90").save

      request = Puppet::Indirector::Request.new(:facts, :search, nil,
                                                {'facts.uptime_days.ge' => '30',
                                                 'facts.uptime_days.le' => '60'})

      terminus.search(request).should =~ ["foo","bar"]
    end
  end
end

