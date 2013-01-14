#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector/certificate_revocation_list/disabled_ca'

describe Puppet::SSL::CertificateRevocationList::DisabledCa do
  def request(type, remote)
    r = Puppet::Indirector::Request.new(:certificate_revocation_list, type, "foo.com", nil)
    if remote
      r.ip   = '10.0.0.1'
      r.node = 'agent.example.com'
    end
    r
  end

  context "when not a CA" do
    before :each do
      Puppet[:ca] = false
      Puppet::SSL::Host.ca_location = :none
    end

    [:find, :head, :search, :save, :destroy].each do |name|
      it "should fail remote #{name} requests" do
        expect { subject.send(name, request(name, true)) }.
          to raise_error Puppet::Error, /is not a CA/
      end

      it "should forward local #{name} requests" do
        Puppet::SSL::CertificateRevocationList.indirection.terminus(:file).expects(name)
        subject.send(name, request(name, false))
      end
    end
  end
end
