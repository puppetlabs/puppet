#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'base64'
require 'cgi'

class TestLogger < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        super
        #Puppet[:debug] = true
        Puppet::Util::Log.newdestination :console
    end

    # Test the log driver manually
    def test_localaddlog
        logger = nil
        assert_nothing_raised {
            logger = Puppet::Network::Server::Logger.new
        }

        msg = nil
        assert_nothing_raised {
            msg = Puppet::Util::Log.create(
                :level => :warning,
                :message => "This is a message"
            )
        }

        assert_nothing_raised {
            logger.addlog(msg)
        }
    end

    # Test it while replicating a remote client
    def test_remoteaddlog
        logger = nil
        assert_nothing_raised {
            logger = Puppet::Network::Server::Logger.new
        }

        msg = nil
        assert_nothing_raised {
            msg = Puppet::Util::Log.create(
                :level => :warning,
                :message => "This is a remote message"
            )
        }

        assert_nothing_raised {
            msg = CGI.escape(YAML.dump(msg))
        }
        assert_nothing_raised {
            logger.addlog(msg, "localhost", "127.0.0.1")
        }
    end

    # Now test it with a real client and server, but not remote
    def test_localclient
        client = nil
        assert_nothing_raised {
            client = Puppet::Network::Client::LogClient.new(:Logger => true)
        }

        msg = nil
        assert_nothing_raised {
            msg = Puppet::Util::Log.create(
                :level => :warning,
                :message => "This is a logclient message"
            )
        }

        msg = CGI.escape(YAML.dump(msg))

        assert_nothing_raised {
            client.addlog(msg, "localhost", "127.0.0.1")
        }
    end

    # And now test over the network
    # This test is disabled, since it doesn't work well and it's not the right
    # solution anyway.
    def disabled_test_logclient
        pid = nil
        clientlog = tempfile()
        serverlog = tempfile()
        Puppet.warning "serverlog is %s" % serverlog
        Puppet::Util::Log.newdestination clientlog
        Puppet::Util::Log.close(:syslog)

        # For testing
        Puppet[:autosign] = true

        logger = nil
        # Create our server
        assert_nothing_raised {
            logger = Puppet::Network::Server.new(
                :Port => @@port,
                :Handlers => {
                    :CA => {}, # so that certs autogenerate
                    :Logger => {}
                }
            )
        }

        # Start our server
        serverpid = fork {
            Puppet::Util::Log.close(clientlog)
            Puppet::Util::Log.newdestination serverlog
            assert_nothing_raised() {
                trap(:INT) { logger.shutdown }
                logger.start
            }
        }
        @@tmppids << serverpid
        sleep(0.5)

        # Start a raw xmlrpc client
        client = nil
        assert_nothing_raised() {
            client = Puppet::Network::Client::LogClient.new(
                :Server => "localhost",
                :Port => @@port
            )
            unless client.readcert
                raise "Could not get certs"
            end
        }
        retval = nil

        {
            :notice => "XMLRPC1",
            :warning => "XMLRPC2",
            :err => "XMLRPC3"
        }.each { |level, str|
            msg = CGI.escape(YAML.dump(Puppet::Util::Log.create(
                :level => level,
                :message => str
            )))
            assert_nothing_raised {
                retval = client.addlog(msg)
            }
        }

        # and now use the normal client action

        # Set the log destination to be the server
        Puppet::Util::Log.newdestination "localhost:%s" % @@port

        # And now do some logging
        assert_nothing_raised {
            Puppet.notice "TEST1"
            Puppet.warning "TEST2"
            Puppet.err "TEST3"
        }

        assert_nothing_raised {
            Process.kill("INT", serverpid)
        }

        assert(FileTest.exists?(serverlog), "Server log does not exist")

        # Give it a bit to flush to disk
        sleep(0.5)
        content = nil
        assert_nothing_raised {
            content = File.read(serverlog)
        }

        %w{TEST1 TEST2 TEST3}.each { |str|
            assert(content =~ %r{#{str}}, "Content does not match %s" % str)
        }
    end
end

# $Id$
