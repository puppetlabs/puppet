#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'

require 'puppet/network/authconfig'

class TestAuthConfig < Test::Unit::TestCase
  include PuppetTest

  def request(call, client, ip)
    r = Puppet::Network::ClientRequest.new(client, ip, false)
    h, m = call.split(".")
    r.handler = h
    r.method = m
    r
  end

  def test_parsingconfigfile
    file = tempfile
    assert(Puppet[:authconfig], "No config path")

    Puppet[:authconfig] = file

    File.open(file, "w") { |f|
      f.puts "[pelementserver.describe]
  allow *.madstop.com
  deny 10.10.1.1

[fileserver]
  allow *.madstop.com
  deny 10.10.1.1

[fileserver.list]
  allow 10.10.1.1
"
    }

    config = nil
    assert_nothing_raised {
      config = Puppet::Network::AuthConfig.new(file)
    }

    assert_nothing_raised {
      assert(config.allowed?(request("pelementserver.describe", "culain.madstop.com", "1.1.1.1")), "Did not allow host")
      assert(! config.allowed?(request("pelementserver.describe", "culain.madstop.com", "10.10.1.1")), "Allowed host")
      assert(config.allowed?(request("fileserver.yay", "culain.madstop.com", "10.1.1.1")), "Did not allow host to fs")
      assert(! config.allowed?(request("fileserver.yay", "culain.madstop.com", "10.10.1.1")), "Allowed host to fs")
      assert(config.allowed?(request("fileserver.list", "culain.madstop.com", "10.10.1.1")), "Did not allow host to fs.list")
    }
  end

  def test_singleton
    auth = nil
    assert_nothing_raised { auth = Puppet::Network::AuthConfig.main }
    assert(auth, "did not get main authconfig")

    other = nil
    assert_nothing_raised { other = Puppet::Network::AuthConfig.main }

          assert_equal(
        auth.object_id, other.object_id,
        
      "did not get same authconfig from class")
  end
end


