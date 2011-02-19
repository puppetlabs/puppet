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

  def test_process
    server = Puppet::Network::Handler.report.new

    # We have to run multiple reports to make sure there's no conflict
    reports = []
    $run = []
    2.times do |i|
      name = "processtest#{i}"
      reports << name

      Report.newreport(name) do
        def process
          $run << self.report_name
        end
      end
    end
    Puppet[:reports] = reports.collect { |r| r.to_s }.join(",")

    report = fakereport

    retval = nil
    assert_nothing_raised {
      retval = server.send(:process, YAML.dump(report))
    }

    reports.each do |name|
      assert($run.include?(name.intern), "Did not run #{name}")
    end

    # Now make sure our server doesn't die on missing reports
    Puppet[:reports] = "fakereport"
    assert_nothing_raised {
      retval = server.send(:process, YAML.dump(report))
    }
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
