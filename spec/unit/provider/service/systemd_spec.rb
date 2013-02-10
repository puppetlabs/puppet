#! /usr/bin/env ruby
#
# Unit testing for the systemd service Provider
#
require 'spec_helper'

describe Puppet::Type.type(:service).provider(:systemd) do
  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
  end

  let :provider do
    described_class.new(:name => 'myservice.service')
  end

  [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      provider.should respond_to(method)
    end
  end


  it 'should return resources from self.instances' do
    described_class.expects(:systemctl).with('list-units', '--full', '--all',  '--no-pager').returns(
      "my_service loaded active running\nmy_other_service loaded active running"
    )
    described_class.instances.map {|provider| provider.name}.should =~ ["my_service","my_other_service"]
  end

  it "(#16451) has command systemctl without being fully qualified" do
    described_class.instance_variable_get(:@commands).
      should include(:systemctl => 'systemctl')
  end

end
