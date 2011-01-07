#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/reports'
require 'puppet/transaction/report'
require 'puppettest'
require 'puppettest/reporttesting'

class TestReports < Test::Unit::TestCase
  include PuppetTest
  include PuppetTest::Reporttesting

  def mkreport
    # First do some work
    objects = []
    6.times do |i|
      file = tempfile

      # Make every third file
      File.open(file, "w") { |f| f.puts "" } if i % 3 == 0


            objects << Puppet::Type.type(:file).new(
                
        :path => file,
        
        :ensure => "file"
      )
    end

    config = mk_catalog(*objects)
    # So the report works out.
    config.retrieval_duration = 0.001
    trans = config.apply

    trans.generate_report
  end

  # Make sure we can use reports as log destinations.
  def test_reports_as_log_destinations
    report = fakereport

    assert_nothing_raised {
      Puppet::Util::Log.newdestination(report)
    }

    # Now make a file for testing logging
    file = Puppet::Type.type(:file).new(:path => tempfile, :ensure => "file")
    file.finish

    log = nil
    assert_nothing_raised {
      log = file.log "This is a message, yo"
    }

    assert(report.logs.include?(log), "Report did not get log message")

    assert_nothing_raised {
      Puppet::Util::Log.close(report)
    }

    log = file.log "This is another message, yo"

    assert(! report.logs.include?(log), "Report got log message after close")
  end

  def test_store_report
    # Create a bunch of log messages in an array.
    report = Puppet::Transaction::Report.new("apply")

    # We have to reuse reporting here because of something going on in the
    # server/report.rb file
    Puppet.settings.use(:main, :master)

    3.times { |i|
      log = Puppet.warning("Report test message #{i}")

      report << log
    }

    assert_nothing_raised do
      report.extend(Puppet::Reports.report(:store))
    end

    yaml = YAML.dump(report)

    file = report.process

    assert(FileTest.exists?(file), "report file did not get created")
    assert_equal(yaml, File.read(file), "File did not get written")
  end

  if Puppet.features.rrd? || Puppet.features.rrd_legacy?
  def test_rrdgraph_report
    Puppet.settings.use(:main, :metrics)
    report = mkreport

    assert(! report.metrics.empty?, "Did not receive any metrics")

    assert_nothing_raised do
      report.extend(Puppet::Reports.report(:rrdgraph))
    end

    assert_nothing_raised {
      report.process
    }

    hostdir = nil
    assert_nothing_raised do
      hostdir = report.hostdir
    end

    assert(hostdir, "Did not get hostdir back")

    assert(FileTest.directory?(hostdir), "Host rrd dir did not get created")
    index = File.join(hostdir, "index.html")
    assert(FileTest.exists?(index), "index file was not created")

    # Now make sure it creaets each of the rrd files
    %w{changes resources time}.each do |type|
      file = File.join(hostdir, "#{type}.rrd")
      assert(FileTest.exists?(file), "Did not create rrd file for #{type}")

      daily = file.sub ".rrd", "-daily.png"
      assert(FileTest.exists?(daily), "Did not make daily graph for #{type}")
    end

  end
  else
  $stderr.puts "Install RRD for metric reporting tests"
  end
end

