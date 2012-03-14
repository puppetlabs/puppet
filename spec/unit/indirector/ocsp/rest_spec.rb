#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/ocsp/rest'

describe Puppet::Indirector::Ocsp::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::Indirector::Ocsp::Rest.superclass.should equal(Puppet::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    Puppet::Indirector::Ocsp::Rest.server_setting.should == :ca_server
  end

  it "should set port_setting to :ca_port" do
    Puppet::Indirector::Ocsp::Rest.port_setting.should == :ca_port
  end

  it "should not use ocsp verification while verifying" do
    Puppet::Indirector::Ocsp::Rest.should_not be_ocsp_verification_enabled
  end
end
