#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'

class TestHandlerRunner < Test::Unit::TestCase
	include PuppetTest

    def mkclient(code)
        master = nil
        client = nil
        Puppet[:code] = code
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Handler.master.new(
                :Local => true
            )
        }

        # and our client
        assert_nothing_raised() {
            client = Puppet::Network::Client.master.new(
                :Master => master
            )
        }

        client
    end

    def setup
        super
        FileUtils.mkdir_p(Puppet[:statedir])
        Puppet[:ignoreschedules] = false
        # Okay, make our manifest
        file = tempfile()
        created = tempfile()
        # We specify the schedule here, because I was having problems with
        # using default schedules.
        @code = %{
                class yayness {
                    schedule { "yayness": period => weekly }
                    file { "#{created}": ensure => file, schedule => yayness }
                }

                include yayness
            }

        @client = mkclient(@code)

        @runner = Puppet::Network::Handler.runner.new
    end

    def test_runner_when_in_foreground
        @client.expects(:run).with(:tags => "mytags", :ignoreschedules => true)

        Process.expects(:newthread).never

        @runner.run("mytags", true, true)
    end

    def test_runner_when_in_background
        @client.expects(:run).with(:tags => "mytags", :ignoreschedules => true)

        Puppet.expects(:newthread).yields

        @runner.run("mytags", true, false)
    end
end
