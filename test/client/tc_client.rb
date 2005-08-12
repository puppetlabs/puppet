if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $:.unshift '../../../../language/trunk/lib'
    $puppetbase = "../../../../language/trunk/"
end

require 'puppet'
require 'puppet/client'
require 'puppet/server'
require 'test/unit'
require 'puppettest.rb'

# $Id$

class TestClient < Test::Unit::TestCase
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        @@tmpfiles = []
    end

    def teardown
        Puppet::Type.allclear
        @@tmpfiles.each { |f|
            if FileTest.exists?(f)
                system("rm -rf %s" % f)
            end
        }
    end

    def test_sslInitWithAutosigningLocalServer
        Puppet[:autosign] = true
        Puppet[:ssldir] = "/tmp/puppetclientcertests"
        @@tmpfiles.push Puppet[:ssldir]

        file = File.join($puppetbase, "examples", "code", "head")

        server = nil
        assert_nothing_raised {
            server = Puppet::Master.new(
                :File => file,
                :Local => true,
                :CA => true
            )
        }
        client = nil
        assert_nothing_raised {
            client = Puppet::Client.new(:Server => server)
        }
        assert_nothing_raised {
            client.initcerts
        }

        certfile = File.join(Puppet[:certdir], [client.fqdn, "pem"].join("."))
        keyfile = File.join(Puppet[:privatekeydir], [client.fqdn, "pem"].join("."))
        publickeyfile = File.join(Puppet[:publickeydir], [client.fqdn, "pem"].join("."))

        assert(File.exists?(keyfile))
        assert(File.exists?(certfile))
        assert(File.exists?(publickeyfile))
    end

    def test_sslInitWithNonsigningLocalServer
        Puppet[:autosign] = false
        Puppet[:ssldir] = "/tmp/puppetclientcertests"
        @@tmpfiles.push Puppet[:ssldir]

        file = File.join($puppetbase, "examples", "code", "head")

        server = nil
        assert_nothing_raised {
            server = Puppet::Master.new(
                :File => file,
                :Local => true,
                :CA => true
            )
        }
        client = nil
        assert_nothing_raised {
            client = Puppet::Client.new(:Server => server)
        }
        certfile = File.join(Puppet[:certdir], [client.fqdn, "pem"].join("."))
        cafile = File.join(Puppet[:certdir], ["ca", "pem"].join("."))
        assert_nil(client.initcerts)
        assert(! File.exists?(certfile))

        ca = nil
        assert_nothing_raised {
            ca = Puppet::SSLCertificates::CA.new()
        }


        csr = nil
        assert_nothing_raised {
            csr = ca.getclientcsr(client.fqdn)
        }

        assert(csr)

        cert = nil
        assert_nothing_raised {
            cert, cacert = ca.sign(csr)
            File.open(certfile, "w") { |f| f.print cert.to_pem }
            File.open(cafile, "w") { |f| f.print cacert.to_pem }
        }

        # this time it should get the cert correctly
        assert_nothing_raised {
            client.initcerts
        }

        # this isn't a very good test, since i just wrote the file out
        assert(File.exists?(certfile))
    end
end
