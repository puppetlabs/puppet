require 'puppet/transaction/report'
require 'puppet/indirector/code'
require 'puppet/reports'

class Puppet::Transaction::Report::Processor < Puppet::Indirector::Code
    desc "Puppet's report processor.  Processes the report with each of
        the report types listed in the 'reports' setting."

    def initialize
        Puppet.settings.use(:main, :reporting, :metrics)
    end

    def save(request)
        process(request.instance)
    end

    private

    # Process the report with each of the configured report types.
    # LAK:NOTE This isn't necessarily the best design, but it's backward
    # compatible and that's good enough for now.
    def process(report)
        return if Puppet[:reports] == "none"

        reports().each do |name|
            if mod = Puppet::Reports.report(name)
                # We have to use a dup because we're including a module in the
                # report.
                newrep = report.dup
                begin
                    newrep.extend(mod)
                    newrep.process
                rescue => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    Puppet.err "Report %s failed: %s" %
                        [name, detail]
                end
            else
                Puppet.warning "No report named '%s'" % name
            end
        end
    end

    # Handle the parsing of the reports attribute.
    def reports
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        x = Puppet[:reports].gsub(/(^\s+)|(\s+$)/, '').split(/\s*,\s*/)
    end
end
