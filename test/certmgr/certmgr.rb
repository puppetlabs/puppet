#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/sslcertificates.rb'
require 'puppettest'
require 'puppettest/certificates'
require 'mocha'

class TestCertMgr < Test::Unit::TestCase
  include PuppetTest::Certificates
  def setup
    super
    #@dir = File.join(Puppet[:certdir], "testing")
    @dir = File.join(@configpath, "certest")
    system("mkdir -p #{@dir}")

    Puppet::Util::SUIDManager.stubs(:asuser).yields
  end

  def testCreateSelfSignedCertificate
    cert = nil
    name = "testing"
    newcert = proc {

            Puppet::SSLCertificates::Certificate.new(
                
        :name => name,
        
        :selfsign => true
      )
    }
    assert_nothing_raised {
      cert = newcert.call
    }
    assert_nothing_raised {
      cert.mkselfsigned
    }

    assert_raise(Puppet::Error) {
      cert.mkselfsigned
    }

    assert_nothing_raised {
      cert.write
    }

    assert(FileTest.exists?(cert.certfile))

    assert_nothing_raised {
      cert.delete
    }

    assert_nothing_raised {
      cert = newcert.call
    }
    assert_nothing_raised {
      cert.mkselfsigned
    }

    assert_nothing_raised {
      cert.delete
    }

  end

  def disabled_testCreateEncryptedSelfSignedCertificate
    cert = nil
    name = "testing"
    keyfile = mkPassFile
    assert_nothing_raised {

            cert = Puppet::SSLCertificates::Certificate.new(
                
        :name => name,
        :selfsign => true,
        
        :capass => keyfile
      )
    }
    assert_nothing_raised {
      cert.mkselfsigned
    }
    assert_nothing_raised {
      cert.mkhash
    }

    assert_raise(Puppet::Error) {
      cert.mkselfsigned
    }

    assert(FileTest.exists?(cert.certfile))
    assert(FileTest.exists?(cert.hash))

    assert_nothing_raised {
      cert.delete
    }

    assert_nothing_raised {
      cert.mkselfsigned
    }

    assert_nothing_raised {
      cert.delete
    }

  end

  def testCreateCA
    ca = nil
    assert_nothing_raised {
      ca = Puppet::SSLCertificates::CA.new
    }

    # make the CA again and verify it doesn't fail because everything
    # still exists
    assert_nothing_raised {
      ca = Puppet::SSLCertificates::CA.new
    }

  end

  def testSignCert
    ca = mkCA()

    cert = nil
    assert_nothing_raised {

            cert = Puppet::SSLCertificates::Certificate.new(
                
        :name => "signedcertest",
        :property => "TN",
        :city => "Nashville",
        :country => "US",
        :email => "luke@madstop.com",
        :org => "Puppet",
        :ou => "Development",
        
        :encrypt => mkPassFile()
      )

    }

    assert_nothing_raised {
      cert.mkcsr
    }

    signedcert = nil
    cacert = nil

    assert_nothing_raised {
      signedcert, cacert = ca.sign(cert.csr)
    }

    assert_instance_of(OpenSSL::X509::Certificate, signedcert)
    assert_instance_of(OpenSSL::X509::Certificate, cacert)

    assert_nothing_raised {
      cert.cert = signedcert
      cert.cacert = cacert
      cert.write
    }
    #system("find #{Puppet[:ssldir]}")
    #system("cp -R #{Puppet[:ssldir]} /tmp/ssltesting")

    output = nil
    assert_nothing_raised {
      output = %x{openssl verify -CAfile #{Puppet[:cacert]} -purpose sslserver #{cert.certfile}}
      #output = %x{openssl verify -CApath #{Puppet[:certdir]} -purpose sslserver #{cert.certfile}}
    }

    assert_equal($CHILD_STATUS,0)
    assert_equal(File.join(Puppet[:certdir], "signedcertest.pem: OK\n"), output)
  end


  def test_interactiveca
    ca = nil

    assert_nothing_raised {
      ca = Puppet::SSLCertificates::CA.new
    }

    # basic initialization
    hostname = "test.hostname.com"
    cert = mkcert(hostname)

    # create the csr
    csr = nil
    assert_nothing_raised {
      csr = cert.mkcsr
    }

    assert_nothing_raised {
      ca.storeclientcsr(csr)
    }

    # store it
    pulledcsr = nil
    assert_nothing_raised {
      pulledcsr = ca.getclientcsr(hostname)
    }

    assert_equal(csr.to_pem, pulledcsr.to_pem)

    signedcert = nil
    assert_nothing_raised {
      signedcert, cacert = ca.sign(csr)
    }

    assert_instance_of(OpenSSL::X509::Certificate, signedcert)
    newsignedcert = nil
    assert_nothing_raised {
      newsignedcert, cacert = ca.getclientcert(hostname)
    }

    assert(newsignedcert)

    assert_equal(signedcert.to_pem, newsignedcert.to_pem)
  end

  def test_cafailures
    ca = mkCA()
    cert = cacert = nil
    assert_nothing_raised {
      cert, cacert = ca.getclientcert("nohost")
    }
    assert_nil(cert)
  end

  def test_crl
    ca = mkCA()
    h1 = mksignedcert(ca, "host1.example.com")
    h2 = mksignedcert(ca, "host2.example.com")

    assert(ca.cert.verify(ca.cert.public_key))
    assert(h1.verify(ca.cert.public_key))
    assert(h2.verify(ca.cert.public_key))

    crl = ca.crl
    assert_not_nil(crl)

    store = mkStore(ca)
    assert( store.verify(ca.cert))
    assert( store.verify(h1, [ca.cert]))
    assert( store.verify(h2, [ca.cert]))

    ca.revoke(h1.serial)

    oldcert = File.read(Puppet.settings[:cacert])
    oldserial = File.read(Puppet.settings[:serial])

    # Recreate the CA from disk
    ca = mkCA()
    newcert = File.read(Puppet.settings[:cacert])
    newserial = File.read(Puppet.settings[:serial])
    assert_equal(oldcert, newcert, "The certs are not equal after making a new CA.")
    assert_equal(oldserial, newserial, "The serials are not equal after making a new CA.")
    store = mkStore(ca)
    assert( store.verify(ca.cert), "Could not verify CA certs after reloading certs.")
    assert(!store.verify(h1, [ca.cert]), "Incorrectly verified revoked cert.")
    assert( store.verify(h2, [ca.cert]), "Could not verify certs with reloaded CA.")

    ca.revoke(h2.serial)
    assert_equal(1, ca.crl.extensions.size)

    # Recreate the CA from disk
    ca = mkCA()
    store = mkStore(ca)
    assert( store.verify(ca.cert))
    assert(!store.verify(h1, [ca.cert]), "first revoked cert passed")
    assert(!store.verify(h2, [ca.cert]), "second revoked cert passed")
  end

  def test_ttl
    cert = mksignedcert
    assert_equal(5 * 365 * 24 * 60 * 60,  cert.not_after - cert.not_before)

    Puppet[:ca_ttl] = 7 * 24 * 60 * 60
    cert = mksignedcert
    assert_equal(7 * 24 * 60 * 60,  cert.not_after - cert.not_before)

    Puppet[:ca_ttl] = "2y"
    cert = mksignedcert
    assert_equal(2 * 365 * 24 * 60 * 60,  cert.not_after - cert.not_before)

    Puppet[:ca_ttl] = "2y"
    cert = mksignedcert
    assert_equal(2 * 365 * 24 * 60 * 60,  cert.not_after - cert.not_before)

    Puppet[:ca_ttl] = "1h"
    cert = mksignedcert
    assert_equal(60 * 60,  cert.not_after - cert.not_before)

    Puppet[:ca_ttl] = "900s"
    cert = mksignedcert
    assert_equal(900,  cert.not_after - cert.not_before)

    # This needs to be last, to make sure that setting ca_days
    # overrides setting ca_ttl
    Puppet[:ca_days] = 3
    cert = mksignedcert
    assert_equal(3 * 24 * 60 * 60,  cert.not_after - cert.not_before)

  end
end

