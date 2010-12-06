#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

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
      assert(Puppet::SSLCertificates::Support.method_defined?(name), "No retrieval method for #{name}")
      maker = "mk_#{name}"
      assert(Puppet::SSLCertificates::Support.method_defined?(maker), "No maker method for #{name}")
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

            assert(
        FileTest.exists?(Puppet[file]),
        
        "Did not create #{file} key file")
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

  # Fixing #1382.  This test will always fail on Darwin, because its
  # FS is case-insensitive.
  unless Facter.value(:operatingsystem) == "Darwin"
    def test_uppercase_files_are_renamed_and_read
      # Write a key out to disk in a file containing upper-case.
      key = OpenSSL::PKey::RSA.new(32)
      should_path = Puppet[:hostprivkey]

      dir, file = File.split(should_path)
      newfile = file.sub(/^([-a-z.0-9]+)\./) { $1.upcase + "."}
      upper_path = File.join(dir, newfile)
p upper_path
      File.open(upper_path, "w") { |f| f.print key.to_s }

      user = CertUser.new

      assert_equal(key.to_s, user.read_key.to_s, "Did not read key in from disk")
      assert(! FileTest.exist?(upper_path), "Upper case file was not removed")
      assert(FileTest.exist?(should_path), "File was not renamed to lower-case file")
      assert_equal(key.to_s, user.read_key.to_s, "Did not read key in from disk")
    end
  end
end
