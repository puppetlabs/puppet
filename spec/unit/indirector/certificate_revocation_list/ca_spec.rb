#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate_revocation_list/ca'

describe Puppet::SSL::CertificateRevocationList::Ca do
  it "should have documentation" do
    Puppet::SSL::CertificateRevocationList::Ca.doc.should be_instance_of(String)
  end

  it "should use the :cacrl setting as the crl location" do
    Puppet.settings.stubs(:use)
    Puppet[:cacrl] = File.expand_path("/request/dir")
    Puppet::SSL::CertificateRevocationList::Ca.new.path("whatever").should == Puppet[:cacrl]
  end
end
