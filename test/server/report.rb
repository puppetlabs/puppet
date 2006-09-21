require 'puppet'
require 'puppet/server/report'
require 'puppet/client/reporter'
require 'puppettest'

class TestReportServer < Test::Unit::TestCase
	include PuppetTest
	Puppet::Util.logmethods(self)

    def mkserver
        server = nil
        assert_nothing_raised {
            server = Puppet::Server::Report.new()
        }
        server
    end

    def mkclient(server = nil)
        server ||= mkserver()
        client = nil
        assert_nothing_raised {
            client = Puppet::Client::Reporter.new(:Report => server)
        }

        client
    end

    def test_report
        # Create a bunch of log messages in an array.
        report = Puppet::Transaction::Report.new

        10.times { |i|
            log = warning("Report test message %s" % i)
            log.tags = %w{a list of tags}
            log.tags << "tag%s" % i

            report.newlog(log)
        }

        # Now make our reporting client
        client = mkclient()

        # Now send the report
        file = nil
        assert_nothing_raised("Reporting failed") {
            file = client.report(report)
        }

        # And make sure our YAML file exists.
        assert(FileTest.exists?(file),
            "Report file did not get created")

        # And then try to reconstitute the report.
        newreport = nil
        assert_nothing_raised("Failed to load report file") {
            newreport = YAML.load(File.read(file))
        }

        # Make sure our report is valid and stuff.
        report.logs.zip(newreport.logs).each do |ol,nl|
            %w{level message time tags source}.each do |method|
                assert_equal(ol.send(method).to_s, nl.send(method).to_s,
                    "%s got changed" % method)
            end
        end
    end

    # Make sure we don't have problems with calling mkclientdir multiple
    # times.
    def test_multiple_clients
        server ||= mkserver()

        %w{hostA hostB hostC}.each do |host|
            dir = tempfile()
            assert_nothing_raised("Could not create multiple host report dirs") {
                server.send(:mkclientdir, host, dir)
            }

            assert(FileTest.directory?(dir),
                "Directory was not created")
        end
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
                Puppet::Server::Report.newreport(:myreport) do |report|
                    $myreportrun = true
                    return report
                end
            }
        }
        Puppet[:reports] = "myreport"

        # Create a server
        server = Puppet::Server::Report.new

        method = nil
        assert_nothing_raised {
            method = Puppet::Server::Report.reportmethod(:myreport)
        }
        assert(method, "Did not get report method")

        assert(! server.respond_to?(method),
            "Server already responds to report method")

        retval = nil
        assert_nothing_raised {
            retval = server.send(:process, YAML.dump("a string"))
        }
        assert($myreportrun, "Did not run report")
        assert(server.respond_to?(method),
            "Server does not respond to report method")

        # Now make sure our server doesn't die on missing reports
        Puppet[:reports] = "fakereport"
        assert_nothing_raised {
            retval = server.send(:process, YAML.dump("a string"))
        }
    end

    def test_reports
        Puppet[:reports] = "myreport"

        # Create a server
        server = Puppet::Server::Report.new

        {"myreport" => ["myreport"],
            " fake, another, yay " => ["fake", "another", "yay"]
        }.each do |str, ary|
            Puppet[:reports] = str
            assert_equal(ary, server.send(:reports))
        end
    end
end

# $Id$

