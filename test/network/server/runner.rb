#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet/network/server/runner'
require 'puppettest'

class TestServerRunner < Test::Unit::TestCase
	include PuppetTest

    def mkclient(file)
        master = nil
        client = nil
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Server::Master.new(
                :Manifest => file,
                :UseNodes => false,
                :Local => true
            )
        }

        # and our client
        assert_nothing_raised() {
            client = Puppet::Network::Client::MasterClient.new(
                :Master => master
            )
        }

        client
    end

    def test_runner
        FileUtils.mkdir_p(Puppet[:statedir])
        Puppet[:ignoreschedules] = false
        # Okay, make our manifest
        file = tempfile()
        created = tempfile()
        File.open(file, "w") do |f|
            f.puts %{
                class yayness {
                    file { "#{created}": ensure => file, schedule => weekly }
                }

                include yayness
            }
        end

        client = mkclient(file)

        runner = nil
        assert_nothing_raised {
            runner = Puppet::Network::Server::Runner.new
        }
        # First: tags
        # Second: ignore schedules true/false
        # Third: background true/false
        # Fourth: whether file should exist true/false
        [
            ["with no backgrounding",
                nil, true, true, true],
            ["in the background",
                nil, true, false, true],
            ["with a bad tag",
                ["coolness"], true, false, false],
            ["with another bad tag",
                "coolness", true, false, false],
            ["with a good tag",
                ["coolness", "yayness"], true, false, true],
            ["with another good tag",
                ["yayness"], true, false, true],
            ["with a third good tag",
                "yayness", true, false, true],
            ["with no tags",
                "", true, false, true],
            ["not ignoring schedules",
                nil, false, false, false],
            ["ignoring schedules",
                nil, true, false, true],
        ].each do |msg, tags, ignore, fg, shouldexist|
            if FileTest.exists?(created)
                File.unlink(created)
            end
            assert_nothing_raised {
                # Try it without backgrounding
                runner.run(tags, ignore, fg)
            }

            unless fg
                Puppet.join
            end

            if shouldexist
                assert(FileTest.exists?(created), "File did not get created " +
                    msg)
            else
                assert(!FileTest.exists?(created), "File got created incorrectly " +
                    msg)
            end
        end
    end
end

# $Id$

