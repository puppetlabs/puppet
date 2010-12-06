#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest/certificates'
require 'puppet/sslcertificates/inventory.rb'
require 'mocha'

class TestCertInventory < Test::Unit::TestCase
  include PuppetTest::Certificates

  Inventory = Puppet::SSLCertificates::Inventory

  def setup
    super
    Puppet::Util::SUIDManager.stubs(:asuser).yields
  end

  def test_format
    cert = mksignedcert

    format = nil
    assert_nothing_raised do
      format = Inventory.format(cert)
    end


      assert(
        format =~ /^0x0001 \S+ \S+ #{cert.subject}/,

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
      assert(init.include?(cert.subject.to_s), "Did not catch #{cert.subject}")
    end
  end

  def test_add
    ca = mkCA
    cert = mksignedcert(ca, "host.domain.com")

    assert_nothing_raised do
      file = mock
      file.expects(:puts).with do |written|
        written.include? cert.subject.to_s
      end
      Puppet::Util::Settings.any_instance.stubs(:write)
      Puppet::Util::Settings.any_instance.expects(:write).
        with(:cert_inventory, 'a').yields(file)

      Puppet::SSLCertificates::Inventory.add(cert)
    end
  end
end

