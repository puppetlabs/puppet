#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe "Puppet::Util::Windows::RootCerts", :if => Puppet::Util::Platform.windows? do
  let(:x509_store) { Puppet::Util::Windows::RootCerts.instance.to_a }

  it "should return at least one X509 certificate" do
    expect(x509_store.to_a.size).to be >= 1
  end

  it "should return an X509 certificate with a subject" do
    x509 = x509_store.first

    expect(x509.subject.to_s).to match(/CN=.*/)
  end
end
