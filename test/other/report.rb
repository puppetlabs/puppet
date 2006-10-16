#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/transaction/report'
require 'puppettest'
require 'puppettest/reporttesting'

class TestReports < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::Reporttesting

    # Make sure we can use reports as log destinations.
    def test_reports_as_log_destinations
        report = fakereport

        assert_nothing_raised {
            Puppet::Log.newdestination(report)
        }

        # Now make a file for testing logging
        file = Puppet::Type.newfile(:path => tempfile(), :ensure => "file")

        log = nil
        assert_nothing_raised {
            log = file.log "This is a message, yo"
        }

        assert(report.logs.include?(log), "Report did not get log message")

        log = Puppet.info "This is a non-sourced message"

        assert(! report.logs.include?(log), "Report got log message")

        assert_nothing_raised {
            Puppet::Log.close(report)
        }

        log = file.log "This is another message, yo"

        assert(! report.logs.include?(log), "Report got log message after close")
    end

    def test_newmetric
        report = nil
        assert_nothing_raised {
            report = Puppet::Transaction::Report.new
        }

        assert_nothing_raised {
            report.newmetric(:mymetric,
                :total => 12,
                :done => 6
            )
        }
    end

    def test_store_report
        # Create a bunch of log messages in an array.
        report = Puppet::Transaction::Report.new

        10.times { |i|
            log = Puppet.info("Report test message %s" % i)
            log.tags = %w{a list of tags}
            log.tags << "tag%s" % i

            report.newlog(log)
        }

        assert_nothing_raised do
            report.extend(Puppet::Server::Report.report(:store))
        end

        yaml = YAML.dump(report)

        file = nil
        assert_nothing_raised {
            file = report.process(yaml)
        }

        assert(FileTest.exists?(file), "report file did not get created")
        assert_equal(yaml, File.read(file), "File did not get written")
    end

    if Puppet::Metric.haverrd?
    def test_rrdgraph_report
        Puppet.config.use(:metrics)
        # First do some work
        objects = []
        25.times do |i|
            file = tempfile()

            # Make every third file
            File.open(file, "w") { |f| f.puts "" } if i % 3 == 0

            objects << Puppet::Type.newfile(
                :path => file,
                :ensure => "file"
            )
        end

        comp = newcomp(*objects)

        trans = nil
        assert_nothing_raised("Failed to create transaction") {
            trans = comp.evaluate
        }

        assert_nothing_raised("Failed to evaluate transaction") {
            trans.evaluate
        }

        report = trans.report

        assert_nothing_raised do
            report.extend(Puppet::Server::Report.report(:rrdgraph))
        end

        assert_nothing_raised {
            report.process
        }

        hostdir = File.join(Puppet[:rrddir], report.host)

        assert(FileTest.directory?(hostdir), "Host rrd dir did not get created")
        index = File.join(hostdir, "index.html")
        assert(FileTest.exists?(index), "index file was not created")
    end
    else
    $stderr.puts "Install RRD for metric reporting tests"
    end
end

# $Id$
