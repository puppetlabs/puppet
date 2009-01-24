#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/lib/puppettest'

require 'puppettest'
require 'puppet/agent'
require 'mocha'

class TestAgent < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        super
        @agent_class = Puppet::Agent
    end

    # Make sure we get a value for timeout
    def test_config_timeout
        master = Puppet::Agent
        time = Integer(Puppet[:configtimeout])
        assert_equal(time, master.timeout, "Did not get default value for timeout")
        assert_equal(time, master.timeout, "Did not get default value for timeout on second run")

        # Reset it
        Puppet[:configtimeout] = "50"
        assert_equal(50, master.timeout, "Did not get changed default value for timeout")
        assert_equal(50, master.timeout, "Did not get changed default value for timeout on second run")

        # Now try an integer
        Puppet[:configtimeout] = 100
        assert_equal(100, master.timeout, "Did not get changed integer default value for timeout")
        assert_equal(100, master.timeout, "Did not get changed integer default value for timeout on second run")
    end

    def test_splay
        client = Puppet::Agent.new

        # Make sure we default to no splay
        client.expects(:sleep).never

        assert_nothing_raised("Failed to call splay") do
            client.send(:splay)
        end

        # Now set it to true and make sure we get the right value
        client = Puppet::Agent.new
        client.expects(:sleep)

        Puppet[:splay] = true
        assert_nothing_raised("Failed to call sleep when splay is true") do
            client.send(:splay)
        end

        # Now try it again
        client = Puppet::Agent.new
        client.expects(:sleep)

        assert_nothing_raised("Failed to call sleep when splay is true with a cached value") do
            client.send(:splay)
        end
    end
end
