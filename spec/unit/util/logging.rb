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

        it "should use the path of any provided resource type" do
            resource = Puppet::Type.type(:mount).new :name => "foo"

            resource.expects(:path).returns "/path/to/mount".to_sym

            Puppet::Util::Log.expects(:create).with { |args| args[:source] == "/path/to/mount" }

            resource.notice "foo"
        end

        it "should use the path of any provided resource parameter" do
            resource = Puppet::Type.type(:mount).new :name => "foo"

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

        [:file, :line, :version, :tags].each do |attr|
            it "should include #{attr} if available" do
                @logger.metaclass.send(:attr_accessor, attr)

                @logger.send(attr.to_s + "=", "myval")

                Puppet::Util::Log.expects(:create).with { |args| args[attr] == "myval" }
                @logger.notice "foo"
            end
        end
    end
end
