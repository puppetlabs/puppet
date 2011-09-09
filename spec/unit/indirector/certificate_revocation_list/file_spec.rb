#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/certificate_revocation_list/file'

describe Puppet::SSL::CertificateRevocationList::File do
  it "should have documentation" do
    Puppet::SSL::CertificateRevocationList::File.doc.should be_instance_of(String)
  end

  it "should always store the file to :hostcrl location" do
    Puppet.settings.expects(:value).with(:hostcrl).returns "/host/crl"
    Puppet.settings.stubs(:use)
    Puppet::SSL::CertificateRevocationList::File.file_location.should == "/host/crl"
  end
end
