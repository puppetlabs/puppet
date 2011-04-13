#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-4-17.
#  Copyright (c) 2008. All rights reserved.

require 'spec_helper'

require 'puppet/ssl/certificate_authority'
require 'tempfile'

describe Puppet::SSL::CertificateAuthority do
  before do
    # Get a safe temporary file
    file = Tempfile.new("ca_integration_testing")
    @dir = file.path
    file.delete

    Puppet.settings[:confdir] = @dir
    Puppet.settings[:vardir] = @dir
    Puppet.settings[:group] = Process.gid

    Puppet::SSL::Host.ca_location = :local
    @ca = Puppet::SSL::CertificateAuthority.new
  end

  after {
    Puppet::SSL::Host.ca_location = :none

    system("rm -rf #{@dir}")
    Puppet.settings.clear

    Puppet::Util::Cacher.expire

    Puppet::SSL::CertificateAuthority.instance_variable_set("@instance", nil)
  }

  it "should create a CA host" do
    @ca.host.should be_ca
  end

  it "should be able to generate a certificate" do
    @ca.generate_ca_certificate

    @ca.host.certificate.should be_instance_of(Puppet::SSL::Certificate)
  end

  it "should be able to generate a new host certificate" do
    @ca.generate("newhost")

    Puppet::SSL::Certificate.indirection.find("newhost").should be_instance_of(Puppet::SSL::Certificate)
  end

  it "should be able to revoke a host certificate" do
    @ca.generate("newhost")

    @ca.revoke("newhost")

    lambda { @ca.verify("newhost") }.should raise_error
  end

  it "should have a CRL" do
    @ca.generate_ca_certificate
    @ca.crl.should_not be_nil
  end

  it "should be able to read in a previously created CRL" do
    @ca.generate_ca_certificate

    # Create it to start with.
    @ca.crl

    Puppet::SSL::CertificateAuthority.new.crl.should_not be_nil
  end

  describe "when signing certificates" do
    before do
      @host = Puppet::SSL::Host.new("luke.madstop.com")

      # We have to provide the key, since when we're in :ca_only mode, we can only interact
      # with the CA key.
      key = Puppet::SSL::Key.new(@host.name)
      key.generate

      @host.key = key
      @host.generate_certificate_request

      path = File.join(Puppet[:requestdir], "luke.madstop.com.pem")
    end

    it "should be able to sign certificates" do
      @ca.sign("luke.madstop.com")
    end

    it "should save the signed certificate" do
      @ca.sign("luke.madstop.com")

      Puppet::SSL::Certificate.indirection.find("luke.madstop.com").should be_instance_of(Puppet::SSL::Certificate)
    end

    it "should be able to sign multiple certificates" do
      @other = Puppet::SSL::Host.new("other.madstop.com")
      okey = Puppet::SSL::Key.new(@other.name)
      okey.generate
      @other.key = okey
      @other.generate_certificate_request

      @ca.sign("luke.madstop.com")
      @ca.sign("other.madstop.com")

      Puppet::SSL::Certificate.indirection.find("other.madstop.com").should be_instance_of(Puppet::SSL::Certificate)
      Puppet::SSL::Certificate.indirection.find("luke.madstop.com").should be_instance_of(Puppet::SSL::Certificate)
    end

    it "should save the signed certificate to the :signeddir" do
      @ca.sign("luke.madstop.com")

      client_cert = File.join(Puppet[:signeddir], "luke.madstop.com.pem")
      File.read(client_cert).should == Puppet::SSL::Certificate.indirection.find("luke.madstop.com").content.to_s
    end

    it "should save valid certificates" do
      @ca.sign("luke.madstop.com")

      unless ssl = Puppet::Util::which('openssl')
        pending "No ssl available"
      else
        ca_cert = Puppet[:cacert]
        client_cert = File.join(Puppet[:signeddir], "luke.madstop.com.pem")
        output = %x{openssl verify -CAfile #{ca_cert} #{client_cert}}
        $CHILD_STATUS.should == 0
      end
    end
  end
end
