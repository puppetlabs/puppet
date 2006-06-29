class Puppet::Client::Reporter < Puppet::Client::ProxyClient
    @drivername = :Report

    # set up the appropriate interface methods
    @handler = Puppet::Server::Report
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:Report)
            hash[:Report] = Puppet::Server::Report.new()
        end

        super(hash)
    end

    def report(array)
        # We receive an array of log events, and we need to convert them into
        # a single big YAML file.

        report = YAML.dump(array)

        unless self.local
            report = CGI.escape(report)
        end

        # Now send the report
        file = @driver.report(report)
    end
end

# $Id$
