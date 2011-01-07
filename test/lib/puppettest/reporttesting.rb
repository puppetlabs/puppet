module PuppetTest::Reporttesting
  def fakereport
    # Create a bunch of log messages in an array.
    report = Puppet::Transaction::Report.new("apply")

    3.times { |i|
      # We have to use warning so that the logs always happen
      log = Puppet.warning("Report test message #{i}")

      report << log
    }

    report
  end
end

