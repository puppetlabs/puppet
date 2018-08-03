#! /usr/bin/env ruby

require 'spec_helper'

test_title = 'Integration Tests for Puppet::Type::Service::Provider::Systemd'

describe test_title, unless: Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:systemd) }

  # TODO: Unfortunately there does not seem a way to stub the executable
  #       checks in the systemd provider because they happen at load time.
  it "should be considered suitable if /bin/systemctl is present", :if => File.executable?('/bin/systemctl') do
    expect(provider_class).to be_suitable
  end

  it "should be considered suitable if /usr/bin/systemctl is present", :if => File.executable?('/usr/bin/systemctl')  do
    expect(provider_class).to be_suitable
  end

  it "should not be cosidered suitable if systemctl is absent",
    :unless => (File.executable?('/bin/systemctl') or File.executable?('/usr/bin/systemctl')) do
    expect(provider_class).not_to be_suitable
  end
end
