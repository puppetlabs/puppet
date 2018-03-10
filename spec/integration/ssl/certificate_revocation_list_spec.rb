#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate_revocation_list'

describe Puppet::SSL::CertificateRevocationList do
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("ca_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir

    Puppet::SSL::Host.ca_location = :local
  end

  after {
    Puppet::SSL::Host.ca_location = :none

    # This is necessary so the terminus instances don't lie around.
    Puppet::SSL::Host.indirection.termini.clear
  }

  it "should be able to read in written out CRLs with no revoked certificates" do
    Puppet::SSL::CertificateAuthority.new

    raise "CRL not created" unless Puppet::FileSystem.exist?(Puppet[:hostcrl])

    crl = Puppet::SSL::CertificateRevocationList.new("crl_int_testing")
    crl.read(Puppet[:hostcrl])
  end
end
