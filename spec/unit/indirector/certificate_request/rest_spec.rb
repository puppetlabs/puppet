#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate_request/rest'

describe Puppet::SSL::CertificateRequest::Rest do
  before do
    @searcher = Puppet::SSL::CertificateRequest::Rest.new
  end

  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::SSL::CertificateRequest::Rest.superclass.should equal(Puppet::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    Puppet::SSL::CertificateRequest::Rest.server_setting.should == :ca_server
  end

  it "should set port_setting to :ca_port" do
    Puppet::SSL::CertificateRequest::Rest.port_setting.should == :ca_port
  end

  it "should use the :ca SRV service" do
    Puppet::SSL::CertificateRequest::Rest.srv_service.should == :ca
  end
end
