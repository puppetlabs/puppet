if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'cgi'
#require 'puppet/server'
require 'facter'
require 'puppet/client'
require 'xmlrpc/client'
require 'test/unit'
require 'puppettest.rb'

# $Id$

if ARGV.length > 0 and ARGV[0] == "short"
    $short = true
else
    $short = false
end

class TestServer < Test::Unit::TestCase
    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
            #paths = Puppet::Type.type(:service).searchpath
            #paths.push "%s/examples/root/etc/init.d" % $puppetbase
            #Puppet::Type.type(:service).setpath(paths)
        end

        @oldconf = Puppet[:puppetconf]
        Puppet[:puppetconf] = "/tmp/servertesting"
        @oldvar = Puppet[:puppetvar]
        Puppet[:puppetvar] = "/tmp/servertesting"

        @@tmpfiles = ["/tmp/servertesting"]
        @@tmppids = []
    end

    def stopservices
        if stype = Puppet::Type.type(:service)
            stype.each { |service|
                service[:running] = false
                service.sync
            }
        end
    end

    def teardown
        Puppet::Type.allclear
        print "\n\n\n\n" if Puppet[:debug]

        @@tmpfiles.each { |file|
            if FileTest.exists?(file)
                system("rm -rf %s" % file)
            end
        }
        @@tmppids.each { |pid|
            system("kill -INT %s" % pid)
        }

        Puppet[:puppetconf] = @oldconf
        Puppet[:puppetvar] = @oldvar
    end

    def test_start
        server = nil
        Puppet[:ssldir] = "/tmp/serverstarttesting"
        Puppet[:autosign] = true
        @@tmpfiles << "/tmp/serverstarttesting"
        port = 8081
        file = File.join($puppetbase, "examples", "code", "head")
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Master => {
                        :File => file,
                    },
                    :Status => nil
                }
            )

        }
        sthread = nil
        assert_nothing_raised() {
            trap(:INT) { server.shutdown }
            sthread = Thread.new {
                server.start
            }
        }
        sleep 1
        assert_nothing_raised {
            server.shutdown
        }
        assert_nothing_raised {
            sthread.join
        }
    end

    # disabled because i can't find a good way to test client connecting
    # i'll have to test the external executables
    def disabled_test_connect_with_threading
        server = nil
        Puppet[:ssldir] = "/tmp/serverconnecttesting"
        Puppet[:autosign] = true
        @@tmpfiles << "/tmp/serverconnecttesting"
        threads = []
        port = 8080
        server = nil
        Thread.abort_on_exception = true
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Status => nil
                }
            )

        }
        sthread = Thread.new {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }

        sleep(3)
        client = nil
        assert_nothing_raised() {
            client = XMLRPC::Client.new("localhost", "/RPC2", port, nil, nil,
                nil, nil, true, 3)
        }
        retval = nil

        clthread = Thread.new {
            assert_nothing_raised() {
                retval = client.call("status.status", "")
            }
        }
        assert_not_nil(clthread.join(5))

        assert_equal(1, retval)
        assert_nothing_raised {
            #system("kill -INT %s" % serverpid)
            server.shutdown
        }

        assert_not_nil(sthread.join(5))

        #Process.wait
    end

    # disabled because i can't find a good way to test client connecting
    # i'll have to test the external executables
    def test_connect_with_fork
        server = nil
        Puppet[:ssldir] = "/tmp/serverconnecttesting"
        Puppet[:autosign] = true
        @@tmpfiles << "/tmp/serverconnecttesting"
        serverpid = nil
        port = 8080
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Status => nil
                }
            )

        }
        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        sleep(3)
        client = nil
        assert_nothing_raised() {
            client = XMLRPC::Client.new("localhost", "/RPC2", port, nil, nil,
                nil, nil, true, 3)
        }
        retval = nil

        assert_nothing_raised() {
            retval = client.call("status.status")
        }

        assert_equal(1, retval)
        #assert_nothing_raised {
        #    system("kill -INT %s" % serverpid)
        #    #server.shutdown
        #}

        #Process.wait
    end

    # disabled because i can't find a good way to test client connecting
    # i'll have to test the external executables
    def test_zzgetconfig_with_fork
        server = nil
        Puppet[:ssldir] = "/tmp/serverconfigtesting"
        Puppet[:autosign] = true
        @@tmpfiles << "/tmp/serverconfigtesting"
        serverpid = nil
        port = 8082
        file = File.join($puppetbase, "examples", "code", "head")
        assert_nothing_raised() {
            server = Puppet::Server.new(
                :Port => port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Master => {
                        :File => file
                    },
                    :Status => nil
                }
            )

        }
        serverpid = fork {
            assert_nothing_raised() {
                #trap(:INT) { server.shutdown; Kernel.exit! }
                trap(:INT) { server.shutdown }
                server.start
            }
        }
        @@tmppids << serverpid

        sleep(3)
        client = nil

        # first use a puppet client object
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Server => "localhost",
                :Port => port
            )
        }
        retval = nil

        assert_nothing_raised() {
            retval = client.getconfig
        }

        # then use a raw rpc client
        assert_nothing_raised() {
            client = XMLRPC::Client.new("localhost", "/RPC2", port, nil, nil,
                nil, nil, true, 3)
        }
        retval = nil

        facts = CGI.escape(Marshal.dump(Puppet::Client::MasterClient.facts))
        assert_nothing_raised() {
            retval = client.call("puppetmaster.getconfig", facts)
        }

        #assert_equal(1, retval)
    end

    # disabled because clients can't seem to connect from in the same process
    def disabled_test_files
        Puppet[:debug] = true if __FILE__ == $0
        Puppet[:puppetconf] = "/tmp/servertestingdir"
        Puppet[:autosign] = true
        @@tmpfiles << Puppet[:puppetconf]
        textfiles { |file|
            Puppet.debug("parsing %s" % file)
            server = nil
            client = nil
            threads = []
            port = 8080
            assert_nothing_raised() {
                # this is the default server setup
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
            assert_nothing_raised() {
                client = Puppet::Client.new(
                    :Server => "localhost",
                    :Port => port
                )
            }

            # start the server
            assert_nothing_raised() {
                trap(:INT) { server.shutdown }
                threads << Thread.new {
                    server.start
                }
            }

            # start the client
            #assert_nothing_raised() {
            #    threads << Thread.new {
            #        client.start
            #    }
            #}

            sleep(1)
            # pull our configuration
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }

            # and shut them both down
            assert_nothing_raised() {
                [server].each { |thing|
                    thing.shutdown
                }
            }

            # make sure everything's complete before we stop
            assert_nothing_raised() {
                threads.each { |thr|
                    thr.join
                }
            }
            assert_nothing_raised() {
                stopservices
            }
            Puppet::Type.allclear
        }
    end
end
