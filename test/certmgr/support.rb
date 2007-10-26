#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppettest'
require 'puppet/sslcertificates/support'
require 'mocha'

class TestCertSupport < Test::Unit::TestCase
    include PuppetTest
    MissingCertificate = Puppet::SSLCertificates::Support::MissingCertificate

    class CertUser
        include Puppet::SSLCertificates::Support
    end

    def setup
        super
        Puppet::Util::SUIDManager.stubs(:asuser).yields
        @user = CertUser.new
        @ca = Puppet::SSLCertificates::CA.new
        @client = Puppet::Network::Client.ca.new(:CA => @ca)
    end

    # Yay, metaprogramming
    def test_keytype
        [:key, :csr, :cert, :ca_cert].each do |name|
            assert(Puppet::SSLCertificates::Support.method_defined?(name),
                "No retrieval method for %s" % name)
            maker = "mk_%s" % name
            assert(Puppet::SSLCertificates::Support.method_defined?(maker),
                "No maker method for %s" % name)
        end
    end

    def test_keys
        keys = [:hostprivkey, :hostpubkey].each { |n| Puppet[n] = tempfile }

        key = nil
        assert_nothing_raised do
            key = @user.key
        end

        assert_logged(:info, /Creating a new SSL/, "Did not log about new key")
        keys.each do |file|
            assert(FileTest.exists?(Puppet[file]),
                "Did not create %s key file" % file)
        end

        # Make sure it's a valid key
        assert_nothing_raised("Created key is invalid") do
            OpenSSL::PKey::RSA.new(File.read(Puppet[:hostprivkey]))
        end

        # now make sure we can read it in
        other = CertUser.new
        assert_nothing_raised("Could not read key in") do
            other.key
        end

        assert_equal(@user.key.to_s, other.key.to_s, "Keys are not equal")
    end

    def test_csr
        csr = nil
        assert_nothing_raised("Could not create csr") do
            csr = @user.csr
        end

        assert(FileTest.exists?(Puppet[:hostcsr]), "did not create csr file")
        assert_instance_of(OpenSSL::X509::Request, csr)
    end

    def test_cacert
        @user = CertUser.new

        assert_raise(MissingCertificate, "Did not fail when missing cacert") do
            @user.ca_cert
        end
    end
end

