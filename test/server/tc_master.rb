if __FILE__ == $0
    if Dir.getwd =~ /test\/server$/
        Dir.chdir("..")
    end

    $:.unshift '../lib'
    $puppetbase = ".."

end

require 'puppet'
require 'puppet/server'
require 'puppet/client'
require 'test/unit'
require 'puppettest.rb'

class TestMaster < Test::Unit::TestCase
    def setup
        if __FILE__ == $0
            Puppet[:loglevel] = :debug
        end

        @@tmpfiles = []
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
    end

    def test_files
        Puppet[:debug] = true if __FILE__ == $0
        Puppet[:puppetconf] = "/tmp/servertestingdir"
        @@tmpfiles << Puppet[:puppetconf]
        textfiles { |file|
            Puppet.debug("parsing %s" % file)
            server = nil
            client = nil
            threads = []
            port = 8080
            master = nil
            assert_nothing_raised() {
                # this is the default server setup
                master = Puppet::Server::Master.new(
                    :File => file,
                    :Local => true
                )
            }
            assert_nothing_raised() {
                client = Puppet::Client::MasterClient.new(
                    :Master => master
                )
            }

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
        }
    end

    def test_defaultmanifest
        Puppet[:debug] = true if __FILE__ == $0
        Puppet[:puppetconf] = "/tmp/servertestingdir"
        @@tmpfiles << Puppet[:puppetconf]
        textfiles { |file|
            Puppet[:manifest] = file
            client = nil
            master = nil
            assert_nothing_raised() {
                # this is the default server setup
                master = Puppet::Server::Master.new(
                    :File => file,
                    :Local => true
                )
            }
            assert_nothing_raised() {
                client = Puppet::Client::MasterClient.new(
                    :Master => master
                )
            }

            # pull our configuration
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }

            break
        }
    end
end

# $Id$

