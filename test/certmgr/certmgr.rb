#!/usr/bin/env ruby -I../lib -I../../lib

require 'puppet'
require 'puppet/sslcertificates.rb'
require 'puppettest'

# so, what kind of things do we want to test?

# we don't need to test function, since we're confident in the
# library tests.  We do, however, need to test how things are actually
# working in the language.

# so really, we want to do things like test that our ast is correct
# and test whether we've got things in the right scopes

class TestCertMgr < Test::Unit::TestCase
    include PuppetTest
    def setup
        super
        #@dir = File.join(Puppet[:certdir], "testing")
        @dir = File.join(@configpath, "certest")
        system("mkdir -p %s" % @dir)
    end

    def mkPassFile()
        keyfile = File.join(@dir, "tmpkeyfile")
        @@tmpfiles << keyfile
        unless FileTest.exists?(@dir)
            system("mkdir -p %s" % @dir)
        end
        File.open(keyfile, "w", 0600) { |f|
            f.print "as;dklj23rlkjzdflij23wr"
        }

        return keyfile
    end

    def mkCA
        ca = nil
        assert_nothing_raised {
            ca = Puppet::SSLCertificates::CA.new()
        }

        return ca
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
            cert = newcert.call()
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
            cert = newcert.call()
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
            ca = Puppet::SSLCertificates::CA.new()
        }

        # make the CA again and verify it doesn't fail because everything
        # still exists
        assert_nothing_raised {
            ca = Puppet::SSLCertificates::CA.new()
        }

    end

    def testSignCert
        ca = mkCA()

        cert = nil
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(
                :name => "signedcertest",
                :state => "TN",
                :city => "Nashville",
                :country => "US",
                :email => "luke@madstop.com",
                :org => "Reductive",
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
        #system("find %s" % Puppet[:ssldir])
        #system("cp -R %s /tmp/ssltesting" % Puppet[:ssldir])

        output = nil
        assert_nothing_raised {
            output = %x{openssl verify -CAfile #{Puppet[:cacert]} -purpose sslserver #{cert.certfile}}
            #output = %x{openssl verify -CApath #{Puppet[:certdir]} -purpose sslserver #{cert.certfile}}
        }

        assert_equal($?,0)
        assert_equal(File.join(Puppet[:certdir], "signedcertest.pem: OK\n"), output)
    end

    def mkcert(hostname)
        cert = nil
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(:name => hostname)
            cert.mkcsr
        }
        
        return cert
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
        h1 = mkSignedCert(ca, "host1.example.com")
        h2 = mkSignedCert(ca, "host2.example.com")
        
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

        # Recreate the CA from disk
        ca = mkCA()
        store = mkStore(ca)
        assert( store.verify(ca.cert))
        assert(!store.verify(h1, [ca.cert]))
        assert( store.verify(h2, [ca.cert]))
        
        ca.revoke(h2.serial)
        assert_equal(1, ca.crl.extensions.size)

        File::open("/tmp/crl.pem", "w") { |f| f.write(ca.crl.to_pem) }
        # Recreate the CA from disk
        ca = mkCA()
        store = mkStore(ca)
        assert( store.verify(ca.cert))
        assert(!store.verify(h1, [ca.cert]))
        assert(!store.verify(h2, [ca.cert]))
    end

    def mkSignedCert(ca, host)
        cert = mkcert(host)
        assert_nothing_raised {
            signedcert, cacert = ca.sign(cert.mkcsr)
            return signedcert
        }
    end

    def mkStore(ca)
        store = OpenSSL::X509::Store.new
        store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
        store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK
        store.add_cert(ca.cert)
        store.add_crl(ca.crl)
        store
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

    def mksignedcert
        ca = mkCA()
        hostname = "ttltest.example.com"

        cert = nil
        assert_nothing_raised {
            cert, cacert = ca.sign(mkcert(hostname).mkcsr)
        }
        return cert
    end
end
