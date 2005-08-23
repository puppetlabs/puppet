if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '../../../../library/trunk/lib/'
    $:.unshift '../../../../library/trunk/test/'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/ca'
require 'puppet/sslcertificates'
require 'openssl'
require 'test/unit'
require 'puppettest.rb'

# $Id$

if ARGV.length > 0 and ARGV[0] == "short"
    $short = true
else
    $short = false
end

class TestCA < Test::Unit::TestCase
    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
            #paths = Puppet::Type.type(:service).searchpath
            #paths.push "%s/examples/root/etc/init.d" % $puppetbase
            #Puppet::Type.type(:service).setpath(paths)
        end

        @@tmpfiles = []
    end

    def teardown
        Puppet::Type.allclear
        print "\n\n" if Puppet[:debug]

        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("rm -rf %s" % file)
            end
        }
    end

    def test_autocertgeneration
        ssldir = "/tmp/testcertdir"
        @@tmpfiles.push ssldir
        assert_nothing_raised {
            Puppet[:autosign] = true
            Puppet[:ssldir] = ssldir
        }
        file = File.join($puppetbase, "examples", "code", "head")
        ca = nil

        assert_nothing_raised {
            ca = Puppet::CA.new()
        }

        key = nil
        csr = nil
        cert = nil
        hostname = "test.domain.com"
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(
                :name => "test.domain.com"
            )
        }
        assert_nothing_raised {
            cert.mkcsr
        }

        certtext = nil
        cacerttext = nil
        assert_nothing_raised {
            certtext, cacerttext = ca.getcert(cert.csr.to_s)
        }

        assert_instance_of(String, certtext)
        assert_instance_of(String, cacerttext)
        x509 = nil
        assert_nothing_raised {
            x509 = OpenSSL::X509::Certificate.new(certtext)
        }
        assert_nothing_raised {
            OpenSSL::X509::Certificate.new(cacerttext)
        }

        # and pull it again, just to make sure we're getting the same thing
        newtext = nil
        assert_nothing_raised {
            newtext, cacerttext = ca.getcert(cert.csr.to_s)
        }

        assert_equal(certtext,newtext)
    end

    def test_storeAndSign
        ssldir = "/tmp/testcertdir"
        @@tmpfiles.push ssldir
        assert_nothing_raised {
            Puppet[:ssldir] = ssldir
            Puppet[:autosign] = false
        }
        file = File.join($puppetbase, "examples", "code", "head")
        ca = nil
        caserv = nil
        assert_nothing_raised {
            caserv = Puppet::CA.new()
        }
        assert_nothing_raised {
            ca = caserv.ca
        }

        key = nil
        csr = nil
        cert = nil
        hostname = "test.domain.com"
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(
                :name => "anothertest.domain.com"
            )
        }
        assert_nothing_raised {
            cert.mkcsr
        }

        certtext = nil
        assert_nothing_raised {
            certtext, cacerttext = caserv.getcert(cert.csr.to_s)
        }

        assert_equal("", certtext)

        x509 = nil
        assert_nothing_raised {
            x509, cacert = ca.sign(cert.csr)
        }
        cert.cert = x509
        assert_nothing_raised {
            cert.write
        }

        assert(File.exists?(cert.certfile))

        newtext = nil
        assert_nothing_raised {
            newtext, cacerttext  = caserv.getcert(cert.csr.to_s)
        }

        assert(newtext)
    end

    def cycleautosign
        ssldir = "/tmp/testcertdir"
        autosign = "/tmp/autosign"
        @@tmpfiles.push ssldir
        @@tmpfiles.push autosign
        assert_nothing_raised {
            Puppet[:ssldir] = ssldir
        }
        file = File.join($puppetbase, "examples", "code", "head")
        caserv = nil

        assert_nothing_raised {
            caserv = Puppet::CA.new()
        }

        key = nil
        csr = nil
        cert = nil
        hostname = "test.domain.com"
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(
                :name => "test.domain.com"
            )
        }
        assert_nothing_raised {
            cert.mkcsr
        }

        certtext = nil
        assert_nothing_raised {
            certtext = caserv.getcert(cert.csr.to_s)
        }

        x509 = nil
        assert_nothing_raised {
            x509 = OpenSSL::X509::Certificate.new(certtext)
        }

        assert(File.exists?(cert.certfile))

        newtext = nil
        assert_nothing_raised {
            newtext = caserv.getcert(cert.csr.to_s)
        }

        assert_equal(certtext,newtext)
    end

    def test_autosign
        autosign = "/tmp/autosign"
        Puppet[:autosign] = "/tmp/autosign"
        @@tmpfiles << autosign
        File.open(autosign, "w") { |f|
            f.puts "hostmatch.domain.com"
            f.puts ".+.other.com"
            f.puts "hostname.+"
        }

        caserv = nil
        file = File.join($puppetbase, "examples", "code", "head")
        assert_nothing_raised {
            caserv = Puppet::CA.new()
        }

        assert(caserv.autosign?("hostmatch.domain.com"))
        assert(caserv.autosign?("fakehost.other.com"))
        assert(caserv.autosign?("hostname.rahtest.boo"))
        assert(caserv.autosign?("hostname.com")) # a tricky one
        assert(!caserv.autosign?("kirby.reductivelabs.com"))
        assert(!caserv.autosign?("culain.domain.com"))
    end
end
