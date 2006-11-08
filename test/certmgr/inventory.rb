#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppettest/certificates'
require 'puppet/sslcertificates/inventory.rb'

class TestCertInventory < Test::Unit::TestCase
    include PuppetTest::Certificates

    Inventory = Puppet::SSLCertificates::Inventory

    def test_format
        cert = mksignedcert

        format = nil
        assert_nothing_raised do
            format = Inventory.format(cert)
        end

        assert(format =~ /^0x0001 \S+ \S+ #{cert.subject}/,
            "Did not create correct format")
    end

    def test_init
        # First create a couple of certificates
        ca = mkCA

        cert1 = mksignedcert(ca, "host1.madstop.com")
        cert2 = mksignedcert(ca, "host2.madstop.com")

        init = nil
        assert_nothing_raised do
            init = Inventory.init
        end

        [cert1, cert2].each do |cert|
            assert(init.include?(cert.subject.to_s),
                "Did not catch %s" % cert.subject.to_s)
        end
    end

    def test_add
        certs = []

        user = Puppet::Util.uid(Puppet[:user])

        ca = mkCA
        3.times do |i|
            cert = mksignedcert(ca, "host#{i.to_s}.domain.com")
            certs << cert

            # Add the cert
            assert_nothing_raised do
                Puppet::SSLCertificates::Inventory.add(cert)
            end

            # Now make sure the cert is in there
            assert(FileTest.exists?(Puppet[:cert_inventory]),
                "Inventory file was not created")

            # And make sure all of our certs are in there
            certs.each do |c|
                assert(
                    File.read(Puppet[:cert_inventory]).include?(cert.subject.to_s),
                    "File does not contain %s" % cert.subject.to_s
                )
            end

            # And make sure the inventory file is owned by the right user
            if Process.uid == 0
                assert_equal(user, File.stat(Puppet[:cert_inventory]).uid)
            end
        end
    end
end

# $Id$
