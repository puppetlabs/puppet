#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/http_server/webrick'
require 'mocha'

class TestWebrickServer < Test::Unit::TestCase
  include PuppetTest::ServerTest

  def setup
    Puppet::Util::SUIDManager.stubs(:asuser).yields
    super
  end

  def teardown
    super
    Puppet::Network::HttpPool.clear_http_instances
  end

  # Make sure we can create a server, and that it knows how to create its
  # certs by default.
  def test_basics
    server = nil
    assert_raise(Puppet::Error, "server succeeded with no cert") do

            server = Puppet::Network::HTTPServer::WEBrick.new(
                
        :Port => @@port,
        
        :Handlers => {
          :Status => nil
        }
      )
    end

    assert_nothing_raised("Could not create simple server") do

            server = Puppet::Network::HTTPServer::WEBrick.new(
                
        :Port => @@port,
        
        :Handlers => {
          :CA => {}, # so that certs autogenerate
          :Status => nil
        }
      )
    end

    assert(server, "did not create server")

    assert(server.cert, "did not retrieve cert")
  end

  # test that we can connect to the server
  # we have to use fork here, because we apparently can't use threads
  # to talk to other threads
  def test_connect_with_fork
    Puppet[:autosign] = true
    serverpid, server = mk_status_server

    # create a status client, and verify it can talk
    client = mk_status_client

    assert(client.cert, "did not get cert for client")

    retval = nil
    assert_nothing_raised("Could not connect to server") {
      retval = client.status
    }
    assert_equal(1, retval)
  end

  def mk_status_client
    client = nil

    assert_nothing_raised {

            client = Puppet::Network::Client.status.new(
                
        :Server => "localhost",
        
        :Port => @@port
      )
    }
    client
  end

  def mk_status_server
    server = nil
    Puppet[:certdnsnames] = "localhost"
    assert_nothing_raised {

            server = Puppet::Network::HTTPServer::WEBrick.new(
                
        :Port => @@port,
        
        :Handlers => {
          :CA => {}, # so that certs autogenerate
          :Status => nil
        }
      )

    }

    pid = fork {
      Puppet.run_mode.stubs(:master?).returns true
      assert_nothing_raised {
        trap(:INT) { server.shutdown }
        server.start
      }
    }
    @@tmppids << pid
    [pid, server]
  end

  def kill_and_wait(pid, file)
    %x{kill -INT #{pid} 2>/dev/null}
    count = 0
    while count < 30 && File::exist?(file)
      count += 1
      sleep(1)
    end
    assert(count < 30, "Killing server #{pid} failed")
  end
end

