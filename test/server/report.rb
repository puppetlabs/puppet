if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server/report'
require 'puppet/client/reporter'
require 'test/unit'
require 'puppettest.rb'

class TestServerRunner < Test::Unit::TestCase
	include TestPuppet
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
        report = []
        10.times { |i|
            report << info("Report test message %s" % i)
            report[-1].tags = %w{a list of tags}
            report[-1].tags << "tag%s" % i
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
        report.zip(newreport).each do |ol,nl|
            %w{level message time tags source}.each do |method|
                assert_equal(ol.send(method), nl.send(method),
                    "%s got changed" % method)
            end
        end
    end
end

# $Id$

