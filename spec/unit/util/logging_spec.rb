#! /usr/bin/env ruby
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
    it "should log the message with warn" do
      @logger.expects(:warning).with do |msg|
        msg =~ /^foo\n/
      end
      @logger.deprecation_warning 'foo'
    end

    it "should only log each offending line once" do
      @logger.expects(:warning).with do |msg|
        msg =~ /^foo\n/
      end .once
      5.times { @logger.deprecation_warning 'foo' }
    end

    it "should only log the first 100 messages" do
      (1..100).each { |i|
        @logger.expects(:warning).with do |msg|
          msg =~ /^#{i}\n/
        end .once
        # since the deprecation warning will only log each offending line once, we have to do some tomfoolery
        # here in order to make it think each of these calls is coming from a unique call stack; we're basically
        # mocking the method that it would normally use to find the call stack.
        @logger.expects(:get_deprecation_offender).returns("deprecation log count test ##{i}")
        @logger.deprecation_warning i
      }
      @logger.expects(:warning).with(101).never
      @logger.deprecation_warning 101
    end
  end

  describe "when formatting exceptions" do
    it "should be able to format a chain of exceptions" do
      exc3 = Puppet::Error.new("original")
      exc3.set_backtrace(["1.rb:4:in `a'","2.rb:2:in `b'","3.rb:1"])
      exc2 = Puppet::Error.new("second", exc3)
      exc2.set_backtrace(["4.rb:8:in `c'","5.rb:1:in `d'","6.rb:3"])
      exc1 = Puppet::Error.new("third", exc2)
      exc1.set_backtrace(["7.rb:31:in `e'","8.rb:22:in `f'","9.rb:9"])
      # whoa ugly
      @logger.format_exception(exc1).should =~ /third
.*7\.rb:31:in `e'
.*8\.rb:22:in `f'
.*9\.rb:9
Wrapped exception:
second
.*4\.rb:8:in `c'
.*5\.rb:1:in `d'
.*6\.rb:3
Wrapped exception:
original
.*1\.rb:4:in `a'
.*2\.rb:2:in `b'
.*3\.rb:1/
    end
  end
end
