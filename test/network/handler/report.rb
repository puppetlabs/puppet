#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppet/network/handler/report'
require 'puppettest/reporttesting'

class TestReportServer < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::Reporttesting

  Report = Puppet::Network::Handler.report
  Puppet::Util.logmethods(self)

  def mkserver
    server = nil
    assert_nothing_raised {
      server = Puppet::Network::Handler.report.new
    }
    server
  end

  def mkclient(server = nil)
    server ||= mkserver
    client = nil
    assert_nothing_raised {
      client = Puppet::Network::Client.report.new(:Report => server)
    }

    client
  end

  def test_reports
    Puppet[:reports] = "myreport"

    # Create a server
    server = Puppet::Network::Handler.report.new

    {"myreport" => ["myreport"],
      " fake, another, yay " => ["fake", "another", "yay"]
    }.each do |str, ary|
      Puppet[:reports] = str
      assert_equal(ary, server.send(:reports))
    end
  end
end
