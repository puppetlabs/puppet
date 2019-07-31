require 'spec_helper'

describe Puppet::Type.type(:service).provider(:systemd), '(integration)' do
  # TODO: Unfortunately there does not seem a way to stub the executable
  #       checks in the systemd provider because they happen at load time.
  it "should be considered suitable if /proc/1/exe is present and points to 'systemd'",
    :if => File.exist?('/proc/1/exe') && Puppet::FileSystem.readlink('/proc/1/exe').include?('systemd') do
    expect(described_class).to be_suitable
  end

  it "should not be considered suitable if /proc/1/exe is present it does not point to 'systemd'",
    :if => File.exist?('/proc/1/exe') && !Puppet::FileSystem.readlink('/proc/1/exe').include?('systemd') do
    expect(described_class).not_to be_suitable
  end

  it "should not be considered suitable if /proc/1/exe is absent",
    :if => !File.exist?('/proc/1/exe') do
    expect(described_class).not_to be_suitable
  end

  it "should not be cosidered suitable if systemctl is absent",
    :unless => (File.executable?('/bin/systemctl') or File.executable?('/usr/bin/systemctl')) do
    expect(described_class).not_to be_suitable
  end
end
