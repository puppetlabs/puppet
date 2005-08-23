#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '../../../../library/trunk/lib/'
    $:.unshift '../../../../library/trunk/test/'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/sslcertificates.rb'
require 'test/unit'
require 'puppettest'

# so, what kind of things do we want to test?

# we don't need to test function, since we're confident in the
# library tests.  We do, however, need to test how things are actually
# working in the language.

# so really, we want to do things like test that our ast is correct
# and test whether we've got things in the right scopes

class TestCertMgr < Test::Unit::TestCase
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        #@dir = File.join(Puppet[:certdir], "testing")
        @dir = "/tmp/puppetcertestingdir"
        Puppet[:ssldir] = @dir
        system("mkdir -p %s" % @dir)
        @@tmpfiles = [@dir]
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
        Puppet[:ssldir] = @dir
        assert_nothing_raised {
            ca = Puppet::SSLCertificates::CA.new()
        }

        return ca
    end

    def teardown
        @@tmpfiles.each { |f|
            if FileTest.exists?(f)
                system("rm -rf %s" % f)
            end
        }
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

        output = nil
        assert_nothing_raised {
            output = %x{openssl verify -CApath #{Puppet[:certdir]} -purpose sslserver #{cert.certfile}}
        }

        assert_equal($?,0)
        assert_equal("\n", output)
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
        Puppet[:ssldir] = "/tmp/puppetinteractivecatest"
        @@tmpfiles.push Puppet[:ssldir]

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
end
