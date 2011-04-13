#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/ssl/host'
require 'puppet/indirector/certificate_status'

describe "Puppet::CertificateStatus::Rest" do
  before do
    @terminus = Puppet::SSL::Host.indirection.terminus(:rest)
  end

  it "should be a terminus on Puppet::SSL::Host" do
    @terminus.should be_instance_of(Puppet::Indirector::CertificateStatus::Rest)
  end
end
