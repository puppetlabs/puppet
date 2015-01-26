#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Util::ExecutionStub do
  it "should use the provided stub code when 'set' is called" do
    Puppet::Util::ExecutionStub.set do |command, options|
      expect(command).to eq(['/bin/foo', 'bar'])
      "stub output"
    end
    expect(Puppet::Util::ExecutionStub.current_value).not_to eq(nil)
    expect(Puppet::Util::Execution.execute(['/bin/foo', 'bar'])).to eq("stub output")
  end

  it "should automatically restore normal execution at the conclusion of each spec test" do
    # Note: this test relies on the previous test creating a stub.
    expect(Puppet::Util::ExecutionStub.current_value).to eq(nil)
  end

  it "should restore normal execution after 'reset' is called" do
    # Note: "true" exists at different paths in different OSes
    if Puppet.features.microsoft_windows?
      true_command = [Puppet::Util.which('cmd.exe').tr('/', '\\'), '/c', 'exit 0']
    else
      true_command = [Puppet::Util.which('true')]
    end
    stub_call_count = 0
    Puppet::Util::ExecutionStub.set do |command, options|
      expect(command).to eq(true_command)
      stub_call_count += 1
      'stub called'
    end
    expect(Puppet::Util::Execution.execute(true_command)).to eq('stub called')
    expect(stub_call_count).to eq(1)
    Puppet::Util::ExecutionStub.reset
    expect(Puppet::Util::ExecutionStub.current_value).to eq(nil)
    expect(Puppet::Util::Execution.execute(true_command)).to eq('')
    expect(stub_call_count).to eq(1)
  end
end
