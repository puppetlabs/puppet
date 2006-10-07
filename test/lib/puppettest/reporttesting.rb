module PuppetTest::Reporttesting
    def fakereport
        # Create a bunch of log messages in an array.
        report = Puppet::Transaction::Report.new

        3.times { |i|
            log = Puppet.info("Report test message %s" % i)
            log.tags = %w{a list of tags}
            log.tags << "tag%s" % i

            report.newlog(log)
        }

        return report
    end
end

# $Id$
