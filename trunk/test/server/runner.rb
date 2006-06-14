if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server/runner'
require 'test/unit'
require 'puppettest.rb'

class TestServerRunner < Test::Unit::TestCase
	include TestPuppet

    def mkclient(file)
        master = nil
        client = nil
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :Manifest => file,
                :UseNodes => false,
                :Local => true
            )
        }

        # and our client
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        client
    end

    def test_runner
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
            runner = Puppet::Server::Runner.new
        }
        # First: tags
        # Second: ignore schedules true/false
        # Third: background true/false
        # Fourth: whether file should exist true/false
        [
            ["with no backgrounding",
                nil, true, false, true],               # no backgrounding
            ["in the background",
                nil, true, true, true],                # in the background
            ["with a bad tag",
                ["coolness"], true, true, false],      # a bad tag
            ["with another bad tag",
                "coolness", true, true, false],        # another bad tag
            ["with a good tag",
                ["coolness", "yayness"], true, true, true],   # a good tag
            ["with another good tag",
                ["yayness"], true, true, true],        # another good tag
            ["with a third good tag",
                "yayness", true, true, true],          # another good tag
            ["not ignoring schedules",
                nil, false, true, false],              # do not ignore schedules
            ["ignoring schedules",
                nil, true, true, true],                # ignore schedules
        ].each do |msg, tags, ignore, bg, shouldexist|
            if FileTest.exists?(created)
                File.unlink(created)
            end
            assert_nothing_raised {
                # Try it without backgrounding
                runner.run(tags, ignore, bg)
            }

            if bg
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

