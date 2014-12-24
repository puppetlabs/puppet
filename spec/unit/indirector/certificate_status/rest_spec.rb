#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/ssl/host'
require 'puppet/indirector/certificate_status'

describe "Puppet::CertificateStatus::Rest" do
  before do
    @terminus = Puppet::SSL::Host.indirection.terminus(:rest)
  end

  it "should be a terminus on Puppet::SSL::Host" do
    expect(@terminus).to be_instance_of(Puppet::Indirector::CertificateStatus::Rest)
  end

  it "should use the :ca SRV service" do
    expect(Puppet::Indirector::CertificateStatus::Rest.srv_service).to eq(:ca)
  end
end
