#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/exec'

describe Puppet::Indirector::Exec do
    before do
        @indirection = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:testing).returns(@indirection)
        @exec_class = Class.new(Puppet::Indirector::Exec) do
            def self.to_s
                "Testing"
            end

            attr_accessor :command
        end

        @searcher = @exec_class.new
        @searcher.command = ["/echo"]
    end

    it "should throw an exception if the command is not an array" do
        @searcher.command = "/usr/bin/echo"
        proc { @searcher.find("foo") }.should raise_error(Puppet::DevError)
    end

    it "should throw an exception if the command is not fully qualified" do
        @searcher.command = ["mycommand"]
        proc { @searcher.find("foo") }.should raise_error(ArgumentError)
    end

    it "should execute the command with the object name as the only argument" do
        @searcher.expects(:execute).with(%w{/echo yay})
        @searcher.find("yay")
    end

    it "should return the output of the script" do
        @searcher.expects(:execute).with(%w{/echo yay}).returns("whatever")
        @searcher.find("yay").should == "whatever"
    end

    it "should return nil when the command produces no output" do
        @searcher.expects(:execute).with(%w{/echo yay}).returns(nil)
        @searcher.find("yay").should be_nil
    end

    it "should be able to execute commands with multiple arguments"
end
