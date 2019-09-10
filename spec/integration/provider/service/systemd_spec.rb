require 'spec_helper'

describe Puppet::Type.type(:service).provider(:systemd), '(integration)' do
  # TODO: Unfortunately there does not seem a way to stub the executable
  #       checks in the systemd provider because they happen at load time.

  it "should be considered suitable if /proc/1/comm is present and contains 'systemd'",
    :if => File.exist?('/proc/1/comm') && Puppet::FileSystem.read('/proc/1/comm').include?('systemd') do
    expect(described_class).to be_suitable
  end

  it "should not be considered suitable if /proc/1/comm is present it does not contain 'systemd'",
    :if => File.exist?('/proc/1/comm') && !Puppet::FileSystem.read('/proc/1/comm').include?('systemd') do
    expect(described_class).not_to be_suitable
  end

  it "should not be considered suitable if /proc/1/comm is absent",
    :if => !File.exist?('/proc/1/comm') do
    expect(described_class).not_to be_suitable
  end
end
