#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/logging'

class LoggingTester
  include Puppet::Util::Logging
end

describe Puppet::Util::Logging do
  before do
    @logger = LoggingTester.new
  end

  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      @logger.should respond_to(level)
    end
  end

  it "should have a method for sending a log with a specified log level" do
    @logger.expects(:to_s).returns "I'm a string!"
    Puppet::Util::Log.expects(:create).with { |args| args[:source] == "I'm a string!" and args[:level] == "loglevel" and args[:message] == "mymessage" }

    @logger.send_log "loglevel", "mymessage"
  end

  describe "when sending a log" do
    it "should use the Log's 'create' entrance method" do
      Puppet::Util::Log.expects(:create)

      @logger.notice "foo"
    end

    it "should send itself converted to a string as the log source" do
      @logger.expects(:to_s).returns "I'm a string!"
      Puppet::Util::Log.expects(:create).with { |args| args[:source] == "I'm a string!" }

      @logger.notice "foo"
    end

    it "should queue logs sent without a specified destination" do
      Puppet::Util::Log.close_all
      Puppet::Util::Log.expects(:queuemessage)

      @logger.notice "foo"
    end

    it "should use the path of any provided resource type" do
      resource = Puppet::Type.type(:host).new :name => "foo"

      resource.expects(:path).returns "/path/to/host".to_sym

      Puppet::Util::Log.expects(:create).with { |args| args[:source] == "/path/to/host" }

      resource.notice "foo"
    end

    it "should use the path of any provided resource parameter" do
      resource = Puppet::Type.type(:host).new :name => "foo"

      param = resource.parameter(:name)

      param.expects(:path).returns "/path/to/param".to_sym

      Puppet::Util::Log.expects(:create).with { |args| args[:source] == "/path/to/param" }

      param.notice "foo"
    end

    it "should send the provided argument as the log message" do
      Puppet::Util::Log.expects(:create).with { |args| args[:message] == "foo" }

      @logger.notice "foo"
    end

    it "should join any provided arguments into a single string for the message" do
      Puppet::Util::Log.expects(:create).with { |args| args[:message] == "foo bar baz" }

      @logger.notice ["foo", "bar", "baz"]
    end

    [:file, :line, :tags].each do |attr|
      it "should include #{attr} if available" do
        @logger.singleton_class.send(:attr_accessor, attr)

        @logger.send(attr.to_s + "=", "myval")

        Puppet::Util::Log.expects(:create).with { |args| args[attr] == "myval" }
        @logger.notice "foo"
      end
    end
  end

  describe "when sending a deprecation warning" do
    before do
      @logger.clear_deprecation_warnings
    end

    it "should the message with warn" do
      @logger.expects(:warning).with('foo')
      @logger.deprecation_warning 'foo'
    end

    it "should only log each unique message once" do
      @logger.expects(:warning).with('foo').once
      5.times { @logger.deprecation_warning 'foo' }
    end

    it "should only log the first 100 messages" do
      (1..100).each { |i|
          @logger.expects(:warning).with(i).once
          @logger.deprecation_warning i
      }
      @logger.expects(:warning).with(101).never
      @logger.deprecation_warning 101
    end
  end
end
