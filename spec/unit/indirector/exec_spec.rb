#! /usr/bin/env ruby
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

  let(:path) { File.expand_path('/echo') }
  let(:arguments) { {:failonfail => true, :combine => false } }

  before :each do
    @searcher = @exec_class.new
    @searcher.command = [path]

    @request = stub 'request', :key => "foo"
  end

  it "should throw an exception if the command is not an array" do
    @searcher.command = path
    expect { @searcher.find(@request) }.to raise_error(Puppet::DevError)
  end

  it "should throw an exception if the command is not fully qualified" do
    @searcher.command = ["mycommand"]
    expect { @searcher.find(@request) }.to raise_error(ArgumentError)
  end

  it "should execute the command with the object name as the only argument" do
    @searcher.expects(:execute).with([path, 'foo'], arguments)
    @searcher.find(@request)
  end

  it "should return the output of the script" do
    @searcher.expects(:execute).with([path, 'foo'], arguments).returns("whatever")
    expect(@searcher.find(@request)).to eq("whatever")
  end

  it "should return nil when the command produces no output" do
    @searcher.expects(:execute).with([path, 'foo'], arguments).returns(nil)
    expect(@searcher.find(@request)).to be_nil
  end

  it "should raise an exception if there's an execution failure" do
    @searcher.expects(:execute).with([path, 'foo'], arguments).raises(Puppet::ExecutionFailure.new("message"))
    expect {
      @searcher.find(@request)
    }.to raise_exception(Puppet::Error, 'Failed to find foo via exec: message')
  end
end
