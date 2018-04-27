#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/exec'

describe Puppet::Indirector::Exec do
  before :all do
    class Puppet::ExecTestModel
      extend Puppet::Indirector
      indirects :exec_test_model
    end

    class Puppet::ExecTestModel::Exec < Puppet::Indirector::Exec
      attr_accessor :command
    end

    Puppet::ExecTestModel.indirection.terminus_class = :exec
  end

  after(:all) do
    Puppet::ExecTestModel.indirection.delete
    Puppet.send(:remove_const, :ExecTestModel)
  end

  let(:terminus) { Puppet::ExecTestModel.indirection.terminus(:exec) }
  let(:indirection) { Puppet::ExecTestModel.indirection }
  let(:model) { Puppet::ExecTestModel }
  let(:path) { File.expand_path('/echo') }
  let(:arguments) { {:failonfail => true, :combine => false } }

  before(:each) { terminus.command = [path] }

  it "should throw an exception if the command is not an array" do
    terminus.command = path
    expect { indirection.find('foo') }.to raise_error(Puppet::DevError)
  end

  it "should throw an exception if the command is not fully qualified" do
    terminus.command = ["mycommand"]
    expect { indirection.find('foo') }.to raise_error(ArgumentError)
  end

  it "should execute the command with the object name as the only argument" do
    terminus.expects(:execute).with([path, 'foo'], arguments)
    indirection.find('foo')
  end

  it "should return the output of the script" do
    terminus.expects(:execute).with([path, 'foo'], arguments).returns("whatever")
    expect(indirection.find('foo')).to eq("whatever")
  end

  it "should return nil when the command produces no output" do
    terminus.expects(:execute).with([path, 'foo'], arguments).returns(nil)
    expect(indirection.find('foo')).to be_nil
  end

  it "should raise an exception if there's an execution failure" do
    terminus.expects(:execute).with([path, 'foo'], arguments).raises(Puppet::ExecutionFailure.new("message"))
    expect {
      indirection.find('foo')
    }.to raise_exception(Puppet::Error, 'Failed to find foo via exec: message')
  end
end
