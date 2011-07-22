#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/certificate_revocation_list'

# REMIND: Fails on windows because there is no user provider yet
describe Puppet::SSL::CertificateRevocationList, :fails_on_windows => true do
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("ca_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir
    Puppet.settings[:group] = Process.gid

    Puppet::SSL::Host.ca_location = :local
  end

  after {
    Puppet::SSL::Host.ca_location = :none

    Puppet.settings.clear

    # This is necessary so the terminus instances don't lie around.
    Puppet::SSL::Host.indirection.termini.clear
  }

  it "should be able to read in written out CRLs with no revoked certificates" do
    ca = Puppet::SSL::CertificateAuthority.new

    raise "CRL not created" unless FileTest.exist?(Puppet[:hostcrl])

    crl = Puppet::SSL::CertificateRevocationList.new("crl_int_testing")
    crl.read(Puppet[:hostcrl])
  end
end
