#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate_revocation_list/rest'

describe Puppet::SSL::CertificateRevocationList::Rest do
  before do
    @searcher = Puppet::SSL::CertificateRevocationList::Rest.new
  end

  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.superclass).to equal(Puppet::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.server_setting).to eq(:ca_server)
  end

  it "should set port_setting to :ca_port" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.port_setting).to eq(:ca_port)
  end

  it "should use the :ca SRV service" do
    expect(Puppet::SSL::CertificateRevocationList::Rest.srv_service).to eq(:ca)
  end
end
