#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/execenv'

describe Puppet::Indirector::Execenv do
  before :all do
    @indirection = stub 'indirection', :name => :testing
    Puppet::Indirector::Indirection.expects(:instance).with(:testing).returns(@indirection)
    module Testing; end
    @exec_class = class Testing::MyExecenv < Puppet::Indirector::Execenv
      attr_accessor :command
      self
    end
  end

  let(:path) { File.expand_path('/echo') }
  let(:arguments) { {:failonfail => true, :combine => false } }

  before :each do
    @searcher = @exec_class.new
    @searcher.command = [path]

    environment = stub 'environment', :name => "bar"
    @request = stub 'request', :key => "foo", :environment => environment
  end

  it "should throw an exception if the command is not an array" do
    @searcher.command = path
    proc { @searcher.find(@request) }.should raise_error(Puppet::DevError)
  end

  it "should throw an exception if the command is not fully qualified" do
    @searcher.command = ["mycommand"]
    proc { @searcher.find(@request) }.should raise_error(ArgumentError)
  end

  it "should execute the command with the object name and environment as the only arguments" do
    @searcher.expects(:execute).with([path, 'foo', 'bar'], arguments)
    @searcher.find(@request)
  end

  it "should return the output of the script" do
    @searcher.expects(:execute).with([path, 'foo', 'bar'], arguments).returns("whatever")
    @searcher.find(@request).should == "whatever"
  end

  it "should return nil when the command produces no output" do
    @searcher.expects(:execute).with([path, 'foo', 'bar'], arguments).returns(nil)
    @searcher.find(@request).should be_nil
  end

  it "should raise an exception if there's an execution failure" do
    @searcher.expects(:execute).with([path, 'foo', 'bar'], arguments).raises(Puppet::ExecutionFailure.new("message"))
    expect {
      @searcher.find(@request)
    }.to raise_exception(Puppet::Error, 'Failed to find foo via exec: message')
  end

end

