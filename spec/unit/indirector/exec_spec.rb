require 'spec_helper'

require 'puppet/indirector/exec'

describe Puppet::Indirector::Exec do
  let(:path) { File.expand_path('/echo') }
  let(:arguments) { {:failonfail => true, :combine => false } }

  before :each do
    @indirection = Puppet::Indirector::Indirection.new(nil, :testing)

    module Testing; end
    @exec_class = class Testing::MyTesting < Puppet::Indirector::Exec
      attr_accessor :command
      self
    end

    @searcher = @exec_class.new
    @searcher.command = [path]

    @request = double('request', :key => "foo")
  end

  after(:each) do
    @indirection.delete
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
    expect(@searcher).to receive(:execute).with([path, 'foo'], arguments)
    @searcher.find(@request)
  end

  it "should return the output of the script" do
    expect(@searcher).to receive(:execute).with([path, 'foo'], arguments).and_return("whatever")
    expect(@searcher.find(@request)).to eq("whatever")
  end

  it "should return nil when the command produces no output" do
    expect(@searcher).to receive(:execute).with([path, 'foo'], arguments).and_return(nil)
    expect(@searcher.find(@request)).to be_nil
  end

  it "should raise an exception if there's an execution failure" do
    expect(@searcher).to receive(:execute).with([path, 'foo'], arguments).and_raise(Puppet::ExecutionFailure.new("message"))
    expect {
      @searcher.find(@request)
    }.to raise_exception(Puppet::Error, 'Failed to find foo via exec: message')
  end
end
