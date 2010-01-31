#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

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
            file = tempfile()

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

        report = Puppet::Transaction::Report.new
        trans.add_metrics_to_report(report)

        return report
    end

    # Make sure we can use reports as log destinations.
    def test_reports_as_log_destinations
        report = fakereport

        assert_nothing_raised {
            Puppet::Util::Log.newdestination(report)
        }

        # Now make a file for testing logging
        file = Puppet::Type.type(:file).new(:path => tempfile(), :ensure => "file")
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

        # We have to reuse reporting here because of something going on in the
        # server/report.rb file
        Puppet.settings.use(:main, :puppetmasterd)

        3.times { |i|
            log = Puppet.warning("Report test message %s" % i)

            report.newlog(log)
        }

        assert_nothing_raised do
            report.extend(Puppet::Reports.report(:store))
        end

        yaml = YAML.dump(report)

        file = report.process

        assert(FileTest.exists?(file), "report file did not get created")
        assert_equal(yaml, File.read(file), "File did not get written")
    end

    if Puppet.features.rrd?
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

    def test_tagmail_parsing
        report = Object.new
        report.extend(Puppet::Reports.report(:tagmail))

        passers = File.join(datadir, "reports", "tagmail_passers.conf")
        assert(FileTest.exists?(passers), "no passers file %s" % passers)

        File.readlines(passers).each do |line|
            assert_nothing_raised("Could not parse %s" % line.inspect) do
                report.parse(line)
            end
        end

        # Now make sure the failers fail
        failers = File.join(datadir, "reports", "tagmail_failers.conf")
        assert(FileTest.exists?(failers), "no failers file %s" % failers)

        File.readlines(failers).each do |line|
            assert_raise(ArgumentError, "Parsed %s" % line.inspect) do
                report.parse(line)
            end
        end
    end

    def test_tagmail_parsing_results
        report = Object.new
        report.extend(Puppet::Reports.report(:tagmail))
        # Now test a few specific lines to make sure we get the results we want
        {
            "tag: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag}, []],
            "tag, other: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag other}, []],
            "tag-other: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag-other}, []],
            "tag, !other: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag}, %w{other}],
            "tag, !other, one, !two: abuse@domain.com" => [%w{abuse@domain.com}, %w{tag one}, %w{other two}],
            "tag: abuse@domain.com, other@domain.com" => [%w{abuse@domain.com other@domain.com}, %w{tag}, []]

        }.each do |line, results|
            assert_nothing_raised("Failed to parse %s" % line.inspect) do
                assert_equal(results, report.parse(line).shift, "line %s returned incorrect results %s" % [line.inspect, results.inspect])
            end
        end
    end

    def test_tagmail_matching
        report = Puppet::Transaction::Report.new
        Puppet::Util::Log.close
        [%w{one}, %w{one two}, %w{one two three}, %w{one two three four}].each do |tags|
            log = Puppet::Util::Log.new(:level => :notice, :message => tags.join(" "), :tags => tags)

            report << log
        end

        list = report.logs.collect { |l| l.to_report }

        report.extend(Puppet::Reports.report(:tagmail))

        {
            [%w{abuse@domain.com}, %w{all}, []] => list,
            [%w{abuse@domain.com}, %w{all}, %w{three}] => list[0..1],
            [%w{abuse@domain.com}, %w{one}, []] => list,
            [%w{abuse@domain.com}, %w{two}, []] => list[1..3],
            [%w{abuse@domain.com}, %w{two}, %w{three}] => list[1..1],
            [%w{abuse@domain.com}, %w{}, %w{one}] => nil
        }.each do |args, expected|
            results = nil
            assert_nothing_raised("Could not match with %s" % args.inspect) do
                results = report.match([args])
            end

            if expected
                assert_equal([args[0], expected.join("\n")], results[0], "did get correct results for %s" % args.inspect)
            else
                assert_nil(results[0], "got a report for %s" % args.inspect)
            end
        end
    end

    def test_summary
        report = mkreport

        summary = report.summary

        %w{Changes Total Resources}.each do |main|
            assert(summary.include?(main), "Summary did not include info for %s" % main)
        end
    end
end

