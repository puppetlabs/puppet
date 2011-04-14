#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/certificate_revocation_list/rest'

describe Puppet::SSL::CertificateRevocationList::Rest do
  before do
    @searcher = Puppet::SSL::CertificateRevocationList::Rest.new
  end

  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::SSL::CertificateRevocationList::Rest.superclass.should equal(Puppet::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    Puppet::SSL::CertificateRevocationList::Rest.server_setting.should == :ca_server
  end

  it "should set port_setting to :ca_port" do
    Puppet::SSL::CertificateRevocationList::Rest.port_setting.should == :ca_port
  end
end
