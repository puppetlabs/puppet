#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

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

    describe "when sending a log" do
        it "should use the Log's 'create' entrance method" do
            Puppet::Util::Log.expects(:create)

            @logger.notice "foo"
        end

        it "should send itself as the log source" do
            Puppet::Util::Log.expects(:create).with { |args| args[:source].equal?(@logger) }

            @logger.notice "foo"
        end

        it "should send the provided argument as the log message" do
            Puppet::Util::Log.expects(:create).with { |args| args[:message] == "foo" }

            @logger.notice "foo"
        end

        it "should join any provided arguments into a single string for the message" do
            Puppet::Util::Log.expects(:create).with { |args| args[:message] == "foo bar baz" }

            @logger.notice ["foo", "bar", "baz"]
        end
    end
end
