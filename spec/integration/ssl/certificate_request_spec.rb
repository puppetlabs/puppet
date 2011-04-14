#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-4-17.
#  Copyright (c) 2008. All rights reserved.

require 'spec_helper'

require 'puppet/ssl/certificate_request'
require 'tempfile'

describe Puppet::SSL::CertificateRequest do
  before do
    # Get a safe temporary file
    file = Tempfile.new("csr_integration_testing")
    @dir = file.path
    file.delete

    Dir.mkdir(@dir)

    Puppet.settings.clear

    Puppet.settings[:confdir] = @dir
    Puppet.settings[:vardir] = @dir
    Puppet.settings[:group] = Process.gid

    Puppet::SSL::Host.ca_location = :none

    @csr = Puppet::SSL::CertificateRequest.new("luke.madstop.com")

    @key = OpenSSL::PKey::RSA.new(512)
  end

  after do
    system("rm -rf #{@dir}")
    Puppet.settings.clear

    # This is necessary so the terminus instances don't lie around.
    Puppet::Util::Cacher.expire
  end

  it "should be able to generate CSRs" do
    @csr.generate(@key)
  end

  it "should be able to save CSRs" do
    Puppet::SSL::CertificateRequest.indirection.save(@csr)
  end

  it "should be able to find saved certificate requests via the Indirector" do
    @csr.generate(@key)
    Puppet::SSL::CertificateRequest.indirection.save(@csr)

    Puppet::SSL::CertificateRequest.indirection.find("luke.madstop.com").should be_instance_of(Puppet::SSL::CertificateRequest)
  end

  it "should save the completely CSR when saving" do
    @csr.generate(@key)
    Puppet::SSL::CertificateRequest.indirection.save(@csr)

    Puppet::SSL::CertificateRequest.indirection.find("luke.madstop.com").content.to_s.should == @csr.content.to_s
  end
end
