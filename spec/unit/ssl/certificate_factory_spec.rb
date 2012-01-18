#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/certificate_factory'

describe Puppet::SSL::CertificateFactory do
  let :serial    do OpenSSL::BN.new('12') end
  let :name      do "example.local" end
  let :x509_name do OpenSSL::X509::Name.new([['CN', name]]) end
  let :key       do Puppet::SSL::Key.new(name).generate end
  let :csr       do
    csr = Puppet::SSL::CertificateRequest.new(name)
    csr.generate(key)
    csr
  end
  let :issuer do
    cert = OpenSSL::X509::Certificate.new
    cert.subject = OpenSSL::X509::Name.new([["CN", 'issuer.local']])
    cert
  end

  describe "when generating the certificate" do
    it "should return a new X509 certificate" do
      subject.build(:server, csr, issuer, serial).should_not ==
        subject.build(:server, csr, issuer, serial)
    end

    it "should set the certificate's version to 2" do
      subject.build(:server, csr, issuer, serial).version.should == 2
    end

    it "should set the certificate's subject to the CSR's subject" do
      cert = subject.build(:server, csr, issuer, serial)
      cert.subject.should eql x509_name
    end

    it "should set the certificate's issuer to the Issuer's subject" do
      cert = subject.build(:server, csr, issuer, serial)
      cert.issuer.should eql issuer.subject
    end

    it "should set the certificate's public key to the CSR's public key" do
      cert = subject.build(:server, csr, issuer, serial)
      cert.public_key.should be_public
      cert.public_key.to_s.should == csr.content.public_key.to_s
    end

    it "should set the certificate's serial number to the provided serial number" do
      cert = subject.build(:server, csr, issuer, serial)
      cert.serial.should == serial
    end

    it "should have 24 hours grace on the start of the cert" do
      cert = subject.build(:server, csr, issuer, serial)
      cert.not_before.should be_within(30).of(Time.now - 24*60*60)
    end

    it "should set the default TTL of the certificate" do
      ttl  = Puppet::SSL::CertificateFactory.ttl
      cert = subject.build(:server, csr, issuer, serial)
      cert.not_after.should be_within(30).of(Time.now + ttl)
    end

    it "should respect a custom TTL for the CA" do
      Puppet[:ca_ttl] = 12
      cert = subject.build(:server, csr, issuer, serial)
      cert.not_after.should be_within(30).of(Time.now + 12)
    end

    it "should build extensions for the certificate" do
      cert = subject.build(:server, csr, issuer, serial)
      cert.extensions.map {|x| x.to_h }.find {|x| x["oid"] == "nsComment" }.should ==
        { "oid"      => "nsComment",
          "value"    => "Puppet Ruby/OpenSSL Internal Certificate",
          "critical" => false }
    end

    # See #2848 for why we are doing this: we need to make sure that
    # subjectAltName is set if the CSR has it, but *not* if it is set when the
    # certificate is built!
    it "should not add subjectAltNames from dns_alt_names" do
      Puppet[:dns_alt_names] = 'one, two'
      # Verify the CSR still has no extReq, just in case...
      csr.request_extensions.should == []
      cert = subject.build(:server, csr, issuer, serial)

      cert.extensions.find {|x| x.oid == 'subjectAltName' }.should be_nil
    end

    it "should add subjectAltName when the CSR requests them" do
      Puppet[:dns_alt_names] = ''

      expect = %w{one two} + [name]

      csr = Puppet::SSL::CertificateRequest.new(name)
      csr.generate(key, :dns_alt_names => expect.join(', '))

      csr.request_extensions.should_not be_nil
      csr.subject_alt_names.should =~ expect.map{|x| "DNS:#{x}"}

      cert = subject.build(:server, csr, issuer, serial)
      san = cert.extensions.find {|x| x.oid == 'subjectAltName' }
      san.should_not be_nil
      expect.each do |name|
        san.value.should =~ /DNS:#{name}\b/i
      end
    end

    # Can't check the CA here, since that requires way more infrastructure
    # that I want to build up at this time.  We can verify the critical
    # values, though, which are non-CA certs. --daniel 2011-10-11
    { :ca            => 'CA:TRUE',
      :terminalsubca => ['CA:TRUE', 'pathlen:0'],
      :server        => 'CA:FALSE',
      :ocsp          => 'CA:FALSE',
      :client        => 'CA:FALSE',
    }.each do |name, value|
      it "should set basicConstraints for #{name} #{value.inspect}" do
        cert = subject.build(name, csr, issuer, serial)
        bc = cert.extensions.find {|x| x.oid == 'basicConstraints' }
        bc.should be
        bc.value.split(/\s*,\s*/).should =~ Array(value)
      end
    end
  end
end
