#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-5-5.
#  Copyright (c) 2008. All rights reserved.

require 'spec_helper'

require 'puppet/ssl/certificate_revocation_list'
require 'tempfile'

describe Puppet::SSL::CertificateRevocationList do
  before do
    # Get a safe temporary file
    file = Tempfile.new("ca_integration_testing")
    @dir = file.path
    file.delete

    Puppet.settings[:confdir] = @dir
    Puppet.settings[:vardir] = @dir
    Puppet.settings[:group] = Process.gid

    Puppet::SSL::Host.ca_location = :local
  end

  after {
    Puppet::SSL::Host.ca_location = :none

    system("rm -rf #{@dir}")
    Puppet.settings.clear

    # This is necessary so the terminus instances don't lie around.
    Puppet::Util::Cacher.expire
  }

  it "should be able to read in written out CRLs with no revoked certificates" do
    ca = Puppet::SSL::CertificateAuthority.new

    raise "CRL not created" unless FileTest.exist?(Puppet[:hostcrl])

    crl = Puppet::SSL::CertificateRevocationList.new("crl_int_testing")
    crl.read(Puppet[:hostcrl])
  end
end
