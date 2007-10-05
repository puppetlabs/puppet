module PuppetTest::Reporttesting
    def fakereport
        # Create a bunch of log messages in an array.
        report = Puppet::Transaction::Report.new

        3.times { |i|
            # We have to use warning so that the logs always happen
            log = Puppet.warning("Report test message %s" % i)
            log.tags = %w{a list of tags}
            log.tags << "tag%s" % i

            report.newlog(log)
        }

        return report
    end
end

