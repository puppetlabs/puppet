class Puppet::Network::Client::Report < Puppet::Network::Client
  @handler = Puppet::Network::Handler.handler(:report)

  def initialize(hash = {})
    hash[:Report] = self.class.handler.new if hash.include?(:Report)

    super(hash)
  end

  # Send our report.  We get the transaction report and convert it to YAML
  # as appropriate.
  def report(transreport)
    report = YAML.dump(transreport)

    report = CGI.escape(report) unless self.local

    # Now send the report
    file = nil
    benchmark(:info, "Sent transaction report") do
      file = @driver.report(report)
    end

    file
  end
end

