require 'spec_helper'

require 'puppet/provider/command'

describe Puppet::Provider::Command do
  let(:executor) { mock('executor') }

  it "exectutes a simple command" do
    executor.expects(:execute).with(["/foo"], {})

    command = Puppet::Provider::Command.new("/foo")
    command.execute(executor)
  end

  it "exectutes a command with extra options" do
    executor.expects(:execute).with(["/foo"], { :option => 1})

    command = Puppet::Provider::Command.new("/foo", { :option => 1 })
    command.execute(executor)
  end
end
