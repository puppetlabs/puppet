#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/server/report'
require 'puppettest/reporttesting'

class TestReportServer < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::Reporttesting

    Report = Puppet::Network::Server::Report
	Puppet::Util.logmethods(self)

    def mkserver
        server = nil
        assert_nothing_raised {
            server = Puppet::Network::Server::Report.new()
        }
        server
    end

    def mkclient(server = nil)
        server ||= mkserver()
        client = nil
        assert_nothing_raised {
            client = Puppet::Network::Client::Reporter.new(:Report => server)
        }

        client
    end

    def test_report_autoloading
        # Create a fake report
        fakedir = tempfile()
        $: << fakedir
        cleanup do $:.delete(fakedir) end

        libdir = File.join(fakedir, "puppet", "reports")
        FileUtils.mkdir_p(libdir)

        $myreportrun = false
        file = File.join(libdir, "myreport.rb")
        File.open(file, "w") { |f| f.puts %{
                Puppet::Network::Server::Report.newreport(:myreport) do
                    def process(report)
                        $myreportrun = true
                        return report
                    end
                end
            }
        }
        Puppet[:reports] = "myreport"

        # Create a server
        server = Puppet::Network::Server::Report.new

        report = nil
        assert_nothing_raised {
            report = Puppet::Network::Server::Report.report(:myreport)
        }
        assert(report, "Did not get report")

    end

    def test_process
        server = Puppet::Network::Server::Report.new

        # We have to run multiple reports to make sure there's no conflict
        reports = []
        $run = []
        5.times do |i|
            name = "processtest%s" % i
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
            assert($run.include?(name.intern), "Did not run %s" % name)
        end

        # Now make sure our server doesn't die on missing reports
        Puppet[:reports] = "fakereport"
        assert_nothing_raised {
            retval = server.send(:process, YAML.dump(report))
        }
    end

    # Make sure reports can specify whether to use yaml or not
    def test_useyaml
        server = Puppet::Network::Server::Report.new

        Report.newreport(:yamlyes, :useyaml => true) do
            def process(report)
                $yamlyes = :yesyaml
            end
        end

        Report.newreport(:yamlno) do
            def process
                $yamlno = :noyaml
            end
        end

        Puppet[:reports] = "yamlyes, yamlno"

        report = fakereport
        yaml = YAML.dump(report)

        assert_nothing_raised do
            server.send(:process, yaml)
        end

        assert_equal(:noyaml, $yamlno, "YAML was used for non-yaml report")
        assert_equal(:yesyaml, $yamlyes, "YAML was not used for yaml report")
    end

    def test_reports
        Puppet[:reports] = "myreport"

        # Create a server
        server = Puppet::Network::Server::Report.new

        {"myreport" => ["myreport"],
            " fake, another, yay " => ["fake", "another", "yay"]
        }.each do |str, ary|
            Puppet[:reports] = str
            assert_equal(ary, server.send(:reports))
        end
    end

    def test_newreport
        name = :newreporttest
        assert_nothing_raised do
            Report.newreport(name) do
                attr_accessor :processed

                def process(report)
                    @processed = report
                end
            end
        end

        assert(Report.report(name), "Did not get report")
        assert_instance_of(Module, Report.report(name))

        obj = "yay"
        obj.extend(Report.report(name))

        assert_nothing_raised do
            obj.process("yay")
        end

        assert_equal("yay", obj.processed)
    end

    # Make sure we get a list of all reports
    def test_report_list
        list = nil
        assert_nothing_raised do
            list = Puppet::Network::Server::Report.reports
        end

        [:rrdgraph, :store, :tagmail].each do |name|
            assert(list.include?(name), "Did not load %s" % name)
        end
    end
end

# $Id$

