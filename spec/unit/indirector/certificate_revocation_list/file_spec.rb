#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate_revocation_list/file'

describe Puppet::SSL::CertificateRevocationList::File do
  it "should have documentation" do
    expect(Puppet::SSL::CertificateRevocationList::File.doc).to be_instance_of(String)
  end

  it "should always store the file to :hostcrl location" do
    crl = File.expand_path("/host/crl")
    Puppet[:hostcrl] = crl
    Puppet.settings.stubs(:use)
    expect(Puppet::SSL::CertificateRevocationList::File.file_location).to eq(crl)
  end
end
