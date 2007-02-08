class Puppet::Network::Client::Reporter < Puppet::Network::Client
    @drivername = :Report

    # set up the appropriate interface methods
    @handler = Puppet::Network::Server::Report

    def initialize(hash = {})
        if hash.include?(:Report)
            hash[:Report] = Puppet::Network::Server::Report.new()
        end

        super(hash)
    end

    # Send our report.  We get the transaction report and convert it to YAML
    # as appropriate.
    def report(transreport)
        report = YAML.dump(transreport)

        unless self.local
            report = CGI.escape(report)
        end

        # Now send the report
        file = nil
        benchmark(:info, "Sent transaction report") do
            file = @driver.report(report)
        end

        file
    end
end

# $Id$
