require 'spec_helper'

require 'puppet/provider/command'

describe Puppet::Provider::Command do
  let(:name) { "the name" }
  let(:the_options) { { :option => 1 } }
  let(:no_options) { {} }
  let(:executable) { "foo" }
  let(:executable_absolute_path) { "/foo/bar" }

  let(:executor) { double('executor') }
  let(:resolver) { double('resolver') }

  let(:path_resolves_to_itself) do
    resolves = Object.new
    class << resolves
      def which(path)
        path
      end
    end
    resolves
  end

  it "executes a simple command" do
    expect(executor).to receive(:execute).with([executable], no_options)

    command = Puppet::Provider::Command.new(name, executable, path_resolves_to_itself, executor)
    command.execute()
  end

  it "executes a command with extra options" do
    expect(executor).to receive(:execute).with([executable], the_options)

    command = Puppet::Provider::Command.new(name, executable, path_resolves_to_itself, executor, the_options)
    command.execute()
  end

  it "executes a command with arguments" do
    expect(executor).to receive(:execute).with([executable, "arg1", "arg2"], no_options)

    command = Puppet::Provider::Command.new(name, executable, path_resolves_to_itself, executor)
    command.execute("arg1", "arg2")
  end

  it "resolves to an absolute path for better execution" do
    expect(resolver).to receive(:which).with(executable).and_return(executable_absolute_path)
    expect(executor).to receive(:execute).with([executable_absolute_path], no_options)

    command = Puppet::Provider::Command.new(name, executable, resolver, executor)
    command.execute()
  end

  it "errors when the executable resolves to nothing" do
    expect(resolver).to receive(:which).with(executable).and_return(nil)
    expect(executor).not_to receive(:execute)

    command = Puppet::Provider::Command.new(name, executable, resolver, executor)

    expect { command.execute() }.to raise_error(Puppet::Error, "Command #{name} is missing")
  end
end
