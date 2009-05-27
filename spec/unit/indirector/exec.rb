#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/exec'

describe Puppet::Indirector::Exec do
    before do
        @indirection = stub 'indirection', :name => :testing
        Puppet::Indirector::Indirection.expects(:instance).with(:testing).returns(@indirection)
        @exec_class = Class.new(Puppet::Indirector::Exec) do
            def self.to_s
                "Testing::Mytype"
            end

            attr_accessor :command
        end

        @searcher = @exec_class.new
        @searcher.command = ["/echo"]

        @request = stub 'request', :key => "foo"
    end

    it "should throw an exception if the command is not an array" do
        @searcher.command = "/usr/bin/echo"
        proc { @searcher.find(@request) }.should raise_error(Puppet::DevError)
    end

    it "should throw an exception if the command is not fully qualified" do
        @searcher.command = ["mycommand"]
        proc { @searcher.find(@request) }.should raise_error(ArgumentError)
    end

    it "should execute the command with the object name as the only argument" do
        @searcher.expects(:execute).with(%w{/echo foo})
        @searcher.find(@request)
    end

    it "should return the output of the script" do
        @searcher.expects(:execute).with(%w{/echo foo}).returns("whatever")
        @searcher.find(@request).should == "whatever"
    end

    it "should return nil when the command produces no output" do
        @searcher.expects(:execute).with(%w{/echo foo}).returns(nil)
        @searcher.find(@request).should be_nil
    end

    it "should return nil and log an error if there's an execution failure" do
        @searcher.expects(:execute).with(%w{/echo foo}).raises(Puppet::ExecutionFailure.new("message"))

        Puppet.expects(:err)
        @searcher.find(@request).should be_nil
    end
end
