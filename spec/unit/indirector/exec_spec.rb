#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/exec'

describe Puppet::Indirector::Exec do
  before :all do
    @indirection = stub 'indirection', :name => :testing
    Puppet::Indirector::Indirection.expects(:instance).with(:testing).returns(@indirection)
    module Testing; end
    @exec_class = class Testing::MyTesting < Puppet::Indirector::Exec
      attr_accessor :command
      self
    end
  end

  before :each do
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
    @searcher.expects(:execute).with(%w{/echo foo}, :combine => false)
    @searcher.find(@request)
  end

  it "should return the output of the script" do
    @searcher.expects(:execute).with(%w{/echo foo}, :combine => false).returns("whatever")
    @searcher.find(@request).should == "whatever"
  end

  it "should return nil when the command produces no output" do
    @searcher.expects(:execute).with(%w{/echo foo}, :combine => false).returns(nil)
    @searcher.find(@request).should be_nil
  end

  it "should raise an exception if there's an execution failure" do
    @searcher.expects(:execute).with(%w{/echo foo}, :combine => false).raises(Puppet::ExecutionFailure.new("message"))

    lambda {@searcher.find(@request)}.should raise_exception(Puppet::Error, 'Failed to find foo via exec: message')
  end
end
