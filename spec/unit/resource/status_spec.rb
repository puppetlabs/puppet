#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/resource/status'

describe Puppet::Resource::Status do
  before do
    @resource = Puppet::Type.type(:file).new :path => "/my/file"
    @status = Puppet::Resource::Status.new(@resource)
  end

  it "should compute type and title correctly" do
    @status.resource_type.should == "File"
    @status.title.should == "/my/file"
  end

  [:node, :file, :line, :current_values, :status, :evaluation_time].each do |attr|
    it "should support #{attr}" do
      @status.send(attr.to_s + "=", "foo")
      @status.send(attr).should == "foo"
    end
  end

  [:skipped, :failed, :restarted, :failed_to_restart, :changed, :out_of_sync, :scheduled].each do |attr|
    it "should support #{attr}" do
      @status.send(attr.to_s + "=", "foo")
      @status.send(attr).should == "foo"
    end

    it "should have a boolean method for determining whehter it was #{attr}" do
      @status.send(attr.to_s + "=", "foo")
      @status.should send("be_#{attr}")
    end
  end

  it "should accept a resource at initialization" do
    Puppet::Resource::Status.new(@resource).resource.should_not be_nil
  end

  it "should set its source description to the resource's path" do
    @resource.expects(:path).returns "/my/path"
    Puppet::Resource::Status.new(@resource).source_description.should == "/my/path"
  end

  [:file, :line].each do |attr|
    it "should copy the resource's #{attr}" do
      @resource.expects(attr).returns "foo"
      Puppet::Resource::Status.new(@resource).send(attr).should == "foo"
    end
  end

  it "should copy the resource's tags" do
    @resource.expects(:tags).returns %w{foo bar}
    Puppet::Resource::Status.new(@resource).tags.should == %w{foo bar}
  end

  it "should always convert the resource to a string" do
    @resource.expects(:to_s).returns "foo"
    Puppet::Resource::Status.new(@resource).resource.should == "foo"
  end

  it "should support tags" do
    Puppet::Resource::Status.ancestors.should include(Puppet::Util::Tagging)
  end

  it "should create a timestamp at its creation time" do
    @status.time.should be_instance_of(Time)
  end

  describe "when sending logs" do
    before do
      Puppet::Util::Log.stubs(:new)
    end

    it "should set the tags to the event tags" do
      Puppet::Util::Log.expects(:new).with { |args| args[:tags] == %w{one two} }
      @status.stubs(:tags).returns %w{one two}
      @status.send_log :notice, "my message"
    end

    [:file, :line].each do |attr|
      it "should pass the #{attr}" do
        Puppet::Util::Log.expects(:new).with { |args| args[attr] == "my val" }
        @status.send(attr.to_s + "=", "my val")
        @status.send_log :notice, "my message"
      end
    end

    it "should use the source description as the source" do
      Puppet::Util::Log.expects(:new).with { |args| args[:source] == "my source" }
      @status.stubs(:source_description).returns "my source"
      @status.send_log :notice, "my message"
    end
  end

  it "should support adding events" do
    event = Puppet::Transaction::Event.new(:name => :foobar)
    @status.add_event(event)
    @status.events.should == [event]
  end

  it "should use '<<' to add events" do
    event = Puppet::Transaction::Event.new(:name => :foobar)
    (@status << event).should equal(@status)
    @status.events.should == [event]
  end

  it "should count the number of successful events and set changed" do
    3.times{ @status << Puppet::Transaction::Event.new(:status => 'success') }
    @status.change_count.should == 3

    @status.changed.should == true
    @status.out_of_sync.should == true
  end

  it "should not start with any changes" do
    @status.change_count.should == 0

    @status.changed.should == false
    @status.out_of_sync.should == false
  end

  it "should not treat failure, audit, or noop events as changed" do
    ['failure', 'audit', 'noop'].each do |s| @status << Puppet::Transaction::Event.new(:status => s) end
    @status.change_count.should == 0
    @status.changed.should == false
  end

  it "should not treat audit events as out of sync" do
    @status << Puppet::Transaction::Event.new(:status => 'audit')
    @status.out_of_sync_count.should == 0
    @status.out_of_sync.should == false
  end

  ['failure', 'noop', 'success'].each do |event_status|
    it "should treat #{event_status} events as out of sync" do
      3.times do @status << Puppet::Transaction::Event.new(:status => event_status) end
      @status.out_of_sync_count.should == 3
      @status.out_of_sync.should == true
    end
  end

  describe "When converting to YAML", :'fails_on_ruby_1.9.2' => true do
    it "should include only documented attributes" do
      @status.file = "/foo.rb"
      @status.line = 27
      @status.evaluation_time = 2.7
      @status.tags = %w{one two}
      @status.to_yaml_properties.should == Puppet::Resource::Status::YAML_ATTRIBUTES.sort
    end
  end
end
