#! /usr/bin/env ruby
require 'spec_helper'
load 'puppet/network/authentication.rb'

class AuthenticationTest
  include Puppet::Network::Authentication
end

describe Puppet::Network::Authentication do
  subject     { AuthenticationTest.new }
  let(:now)   { Time.now }
  let(:cert)  { Puppet::SSL::Certificate.new('cert') }
  let(:host)  { stub 'host', :certificate => cert }

  # this is necessary since the logger is a class variable, and it needs to be stubbed
  def reload_module
    load 'puppet/network/authentication.rb'
  end

  describe "when warning about upcoming expirations" do
    before do
      Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(false)
      Puppet::FileSystem.stubs(:exist?).returns(false)
    end

    it "should check the expiration of the CA certificate" do
      ca = stub 'ca', :host => host
      Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)
      Puppet::SSL::CertificateAuthority.stubs(:instance).returns(ca)
      cert.expects(:near_expiration?).returns(false)
      subject.warn_if_near_expiration
    end

    context "when examining the local host" do
      before do
        Puppet::SSL::Host.stubs(:localhost).returns(host)
        Puppet::FileSystem.stubs(:exist?).with(Puppet[:hostcert]).returns(true)
      end

      it "should not load the localhost certificate if the local CA certificate is missing" do
        # Redmine-21869: Infinite recursion occurs if CA cert is missing.
        Puppet::FileSystem.stubs(:exist?).with(Puppet[:localcacert]).returns(false)
        host.unstub(:certificate)
        host.expects(:certificate).never
        subject.warn_if_near_expiration
      end

      it "should check the expiration of the localhost certificate if the local CA certificate is present" do
        Puppet::FileSystem.stubs(:exist?).with(Puppet[:localcacert]).returns(true)
        cert.expects(:near_expiration?).returns(false)
        subject.warn_if_near_expiration
      end
    end

    it "should check the expiration of any certificates passed in as arguments" do
      cert.expects(:near_expiration?).twice.returns(false)
      subject.warn_if_near_expiration(cert, cert)
    end

    it "should accept instances of OpenSSL::X509::Certificate" do
      raw_cert = stub 'cert'
      raw_cert.stubs(:is_a?).with(OpenSSL::X509::Certificate).returns(true)
      Puppet::SSL::Certificate.stubs(:from_instance).with(raw_cert).returns(cert)
      cert.expects(:near_expiration?).returns(false)
      subject.warn_if_near_expiration(raw_cert)
    end

    it "should use a rate-limited logger for expiration warnings that uses `runinterval` as its interval" do
      Puppet::Util::Log::RateLimitedLogger.expects(:new).with(Puppet[:runinterval])
      reload_module
    end

    context "in the logs" do
      let(:logger) { stub 'logger' }

      before do
        Puppet::Util::Log::RateLimitedLogger.stubs(:new).returns(logger)
        reload_module
        cert.stubs(:near_expiration?).returns(true)
        cert.stubs(:expiration).returns(now)
        cert.stubs(:unmunged_name).returns('foo')
      end

      after(:all) do
        reload_module
      end

      it "should log a warning if a certificate's expiration is near" do
        logger.expects(:warning)
        subject.warn_if_near_expiration(cert)
      end

      it "should use the certificate's unmunged name in the message" do
        logger.expects(:warning).with { |message| message.include? 'foo' }
        subject.warn_if_near_expiration(cert)
      end

      it "should show certificate's expiration date in the message using ISO 8601 format" do
        logger.expects(:warning).with { |message| message.include? now.strftime('%Y-%m-%dT%H:%M:%S%Z') }
        subject.warn_if_near_expiration(cert)
      end
    end
  end
end
