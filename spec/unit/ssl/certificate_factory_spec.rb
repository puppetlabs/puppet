#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/certificate_factory'

describe Puppet::SSL::CertificateFactory do
  before do
    @cert_type = mock 'cert_type'
    @name = mock 'name'
    @csr = stub 'csr', :subject => @name
    @issuer = mock 'issuer'
    @serial = mock 'serial'

    @factory = Puppet::SSL::CertificateFactory.new(@cert_type, @csr, @issuer, @serial)
  end

  describe "when initializing" do
    it "should set its :cert_type to its first argument" do
      @factory.cert_type.should equal(@cert_type)
    end

    it "should set its :csr to its second argument" do
      @factory.csr.should equal(@csr)
    end

    it "should set its :issuer to its third argument" do
      @factory.issuer.should equal(@issuer)
    end

    it "should set its :serial to its fourth argument" do
      @factory.serial.should equal(@serial)
    end

    it "should set its name to the subject of the csr" do
      @factory.name.should equal(@name)
    end
  end

  describe "when generating the certificate" do
    before do
      @cert = mock 'cert'

      @cert.stub_everything

      @factory.stubs :build_extensions

      @factory.stubs :set_ttl

      @issuer_name = mock 'issuer_name'
      @issuer.stubs(:subject).returns @issuer_name

      @public_key = mock 'public_key'
      @csr.stubs(:public_key).returns @public_key

      OpenSSL::X509::Certificate.stubs(:new).returns @cert
    end

    it "should return a new X509 certificate" do
      OpenSSL::X509::Certificate.expects(:new).returns @cert
      @factory.result.should equal(@cert)
    end

    it "should set the certificate's version to 2" do
      @cert.expects(:version=).with 2
      @factory.result
    end

    it "should set the certificate's subject to the CSR's subject" do
      @cert.expects(:subject=).with @name
      @factory.result
    end

    it "should set the certificate's issuer to the Issuer's subject" do
      @cert.expects(:issuer=).with @issuer_name
      @factory.result
    end

    it "should set the certificate's public key to the CSR's public key" do
      @cert.expects(:public_key=).with @public_key
      @factory.result
    end

    it "should set the certificate's serial number to the provided serial number" do
      @cert.expects(:serial=).with @serial
      @factory.result
    end

    it "should build extensions for the certificate" do
      @factory.expects(:build_extensions)
      @factory.result
    end

    it "should set the ttl of the certificate" do
      @factory.expects(:set_ttl)
      @factory.result
    end
  end

  describe "when building extensions" do
    it "should have tests"
  end

  describe "when setting the ttl" do
    it "should have tests"
  end
end
