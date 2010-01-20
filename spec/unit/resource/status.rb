#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/resource/status'

describe Puppet::Resource::Status do
    before do
        @resource = Puppet::Type.type(:file).new :path => "/my/file"
        @status = Puppet::Resource::Status.new(@resource)
    end

    [:node, :version, :file, :line, :current_values, :skipped_reason, :status, :evaluation_time, :change_count].each do |attr|
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

    [:file, :line, :version].each do |attr|
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

        [:file, :line, :version].each do |attr|
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
end
