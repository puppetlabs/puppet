if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
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
        @@tmppids = []
    end

    def teardown
        Puppet::Type.allclear
        @@tmpfiles.each { |f|
            if FileTest.exists?(f)
                system("rm -rf %s" % f)
            end
        }

        @@tmppids.each { |pid|
            %x{kill -INT #{pid} 2>/dev/null}
        }
    end

    def test_sslInitWithAutosigningLocalServer
        Puppet[:autosign] = true
        Puppet[:ssldir] = "/tmp/puppetclientcertests"
        @@tmpfiles.push Puppet[:ssldir]
        @@tmpfiles.push "/tmp/puppetclienttesting"
        file = "/tmp/testingmanifest.pp"
        File.open(file, "w") { |f|
            f.puts '
file { "/tmp/puppetclienttesting": create => true, mode => 755 }
'
        }

        @@tmpfiles << file
        port = 8085

        server = nil
        assert_nothing_raised {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Master => {
                        :File => file,
                    },
                }
            )
        }

        spid = fork {
            trap(:INT) { server.shutdown }
            server.start
        }

        @@tmppids << spid
        client = nil
        assert_nothing_raised {
            client = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => port
            )
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

        assert_nothing_raised("Client could not retrieve configuration") {
            client.getconfig
        }

        assert_nothing_raised("Client could not apply configuration") {
            client.apply
        }

        assert(FileTest.exists?("/tmp/puppetclienttesting"),
            "Applied file does not exist")
    end

    # disabled because the server needs to have its certs in place
    # in order to start at all
    # i don't think this test makes much sense anyway
    def disabled_test_sslInitWithNonsigningLocalServer
        Puppet[:autosign] = false
        Puppet[:ssldir] = "/tmp/puppetclientcertests"
        @@tmpfiles.push Puppet[:ssldir]

        file = File.join($puppetbase, "examples", "code", "head")

        server = nil
        port = 8086
        assert_nothing_raised {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Master => {
                        :File => file,
                    },
                }
            )
        }

        spid = fork {
            trap(:INT) { server.shutdown }
            server.start
        }

        @@tmppids << spid
        client = nil
        assert_nothing_raised {
            client = Puppet::Client.new(:Server => "localhost", :Port => port)
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
