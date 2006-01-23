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
	include ServerTest
    # a single run through of connect, auth, etc.
    def test_sslInitWithAutosigningLocalServer
        # autosign everything, for simplicity
        Puppet[:autosign] = true

        # create a server to which to connect
        mkserver()

        # create our client
        client = nil
        assert_nothing_raised {
            client = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        # get our certs
        assert_nothing_raised {
            client.initcerts
        }

        # make sure all of our cert files exist
        certfile = File.join(Puppet[:certdir], [client.fqdn, "pem"].join("."))
        keyfile = File.join(Puppet[:privatekeydir], [client.fqdn, "pem"].join("."))
        publickeyfile = File.join(Puppet[:publickeydir], [client.fqdn, "pem"].join("."))

        assert(File.exists?(keyfile))
        assert(File.exists?(certfile))
        assert(File.exists?(publickeyfile))

        # verify we can retrieve the configuration
        assert_nothing_raised("Client could not retrieve configuration") {
            client.getconfig
        }

        # and apply it
        assert_nothing_raised("Client could not apply configuration") {
            client.apply
        }

        # and verify that it did what it was supposed to
        assert(FileTest.exists?(@createdfile),
            "Applied file does not exist")
    end


    # here we create two servers; we 
    def test_failureWithUntrustedCerts
        Puppet[:autosign] = true

        # create a pair of clients with no certs
        nonemaster = nil
        assert_nothing_raised {
            nonemaster = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        nonebucket = nil
        assert_nothing_raised {
            nonebucket = Puppet::Client::Dipper.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        # create a ca so we can create a set of certs
        ca = nil
        assert_nothing_raised {
            ca = Puppet::Client::CAClient.new(:CA => true, :Local => true)
            ca.requestcert
        }

        # initialize our clients with this set of certs
        certmaster = nil
        assert_nothing_raised {
            certmaster = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        certbucket = nil
        assert_nothing_raised {
            certbucket = Puppet::Client::Dipper.new(
                :Server => "localhost",
                :Port => @@port
            )
        }

        # clean up the existing certs, so the server creates a new CA
        system("rm -rf %s" % Puppet[:ssldir])

        # start our server
        mkserver

        # now verify that our client cannot do non-cert operations
        # because its certs are signed by a different CA
        assert_raise(Puppet::Error,
            "Client was allowed to call getconfig with no certs") {
            nonemaster.getconfig
        }
        assert_raise(Puppet::Error,
            "Client was allowed to call getconfig with untrusted certs") {
            certmaster.getconfig
        }

        assert_raise(Puppet::NetworkClientError,
            "Client was allowed to call backup with no certs") {
            nonebucket.backup("/etc/passwd")
        }
        assert_raise(Puppet::NetworkClientError,
            "Client was allowed to call backup with untrusted certs") {
            certbucket.backup("/etc/passwd")
        }
    end

    # disabled because the server needs to have its certs in place
    # in order to start at all
    # i don't think this test makes much sense anyway
    def disabled_test_sslInitWithNonsigningLocalServer
        Puppet[:autosign] = false
        Puppet[:ssldir] = tempfile()
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
