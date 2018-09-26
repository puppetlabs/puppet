#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:service).provider(:windows), '(integration)',
  :if => Puppet.features.microsoft_windows? do

  require 'puppet/util/windows'

  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
  end

  context 'should return valid values when querying a service that does not exist' do
    let(:service) do
      Puppet::Type.type(:service).new(:name => 'foobarservice1234')
    end

    it "with :false when asked if enabled" do
      expect(service.provider.enabled?).to eql(:false)
    end

    it "with :stopped when asked about status" do
      expect(service.provider.status).to eql(:stopped)
    end
  end

  context 'should return valid values when querying a service that does exist' do
    let(:service) do
      # This service should be ubiquitous across all supported Windows platforms
      Puppet::Type.type(:service).new(:name => 'lmhosts')
    end

    it "with a valid enabled? value when asked if enabled" do
      expect([:true, :false, :manual]).to include(service.provider.enabled?)
    end

    it "with a valid status when asked about status" do
      expect([
        :running,
        :'continue pending',
        :'pause pending',
        :paused,
        :running,
        :'start pending',
        :'stop pending',
        :stopped]).to include(service.provider.status)
    end
  end
end
