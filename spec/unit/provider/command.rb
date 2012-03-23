require 'spec_helper'

require 'puppet/provider/command'

describe Puppet::Provider::Command do
  let(:the_options) { { :option => 1 } }
  let(:no_options) { {} }
  let(:executable) { "/foo" }
  let(:executor) { mock('executor') }

  it "executes a simple command" do
    executor.expects(:execute).with([executable], no_options)

    command = Puppet::Provider::Command.new(executable)
    command.execute(executor)
  end

  it "executes a command with extra options" do
    executor.expects(:execute).with([executable], the_options)

    command = Puppet::Provider::Command.new(executable, the_options)
    command.execute(executor)
  end

  it "executes a command with arguments" do
    executor.expects(:execute).with([executable, "arg1", "arg2"], no_options)

    command = Puppet::Provider::Command.new(executable)
    command.execute(executor, "arg1", "arg2")
  end
end
