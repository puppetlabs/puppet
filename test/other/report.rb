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
        file.finish

        log = nil
        assert_nothing_raised {
            log = file.log "This is a message, yo"
        }

        assert(report.logs.include?(log), "Report did not get log message")

        log = Puppet.warning "This is a non-sourced message"

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
        
        # We have to reuse reporting here because of something going on in the server/report.rb file
        Puppet.config.use(:reporting)

        3.times { |i|
            log = Puppet.warning("Report test message %s" % i)
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

    if Puppet.features.rrd?
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
            file = File.join(hostdir, "%s.rrd" % type)
            assert(FileTest.exists?(file), "Did not create rrd file for %s" % type)

            daily = file.sub ".rrd", "-daily.png"
            assert(FileTest.exists?(daily),
                "Did not make daily graph for %s" % type)
        end

    end
    else
    $stderr.puts "Install RRD for metric reporting tests"
    end
end

# $Id$
