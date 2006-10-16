require 'puppet'
require 'puppet/client'
require 'puppet/server'
require 'puppettest'

class TestClient < Test::Unit::TestCase
    include PuppetTest::ServerTest
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
        # make a new ssldir for it
        ca = nil
        assert_nothing_raised {
            ca = Puppet::Client::CA.new(
                :CA => true, :Local => true
            )
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

        # Create a new ssl root.
        confdir = tempfile()
        Puppet[:ssldir] = confdir
        Puppet.config.mkdir(:ssldir)
        Puppet.config.clearused
        Puppet.config.use(:certificates, :ca)

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

    def test_classfile
        manifest = tempfile()

        File.open(manifest, "w") do |file|
            file.puts "class yaytest {}\n class bootest {}\n include yaytest, bootest"
        end

        master = client = nil
        assert_nothing_raised() {
            master = Puppet::Server::Master.new(
                :Manifest => manifest,
                :UseNodes => false,
                :Local => false
            )
        }
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        # Fake that it's local, so it creates the class file
        client.local = false

        assert_nothing_raised {
            client.getconfig
        }

        assert(FileTest.exists?(Puppet[:classfile]), "Class file does not exist")

        classes = File.read(Puppet[:classfile]).split("\n")

        assert_equal(%w{bootest yaytest}, classes.sort)
    end

    def test_setpidfile
        $clientrun = false
        newclass = Class.new(Puppet::Client) do
            def run
                $clientrun = true
            end

            def initialize
            end
        end

        inst = newclass.new

        assert_nothing_raised {
            inst.start
        }

        assert(FileTest.exists?(inst.pidfile),
               "PID file was not created")
    end
end

# $Id$
