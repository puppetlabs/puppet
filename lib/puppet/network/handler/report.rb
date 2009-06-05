require 'puppet/util/instance_loader'
require 'puppet/reports'

# A simple server for triggering a new run on a Puppet client.
class Puppet::Network::Handler
    class Report < Handler
        desc "Accepts a Puppet transaction report and processes it."

        @interface = XMLRPC::Service::Interface.new("puppetreports") { |iface|
            iface.add_method("string report(array)")
        }

        # Add a new report type.
        def self.newreport(name, options = {}, &block)
            Puppet.warning "The interface for registering report types has changed; use Puppet::Reports.register_report for report type %s" % name
            Puppet::Reports.register_report(name, options, &block)
        end

        def initialize(*args)
            super
            Puppet.settings.use(:main, :reporting, :metrics)
        end

        # Accept a report from a client.
        def report(report, client = nil, clientip = nil)
            # Unescape the report
            unless @local
                report = CGI.unescape(report)
            end

            Puppet.info "Processing reports %s for %s" % [reports().join(", "), client]
            begin
                process(report)
            rescue => detail
                Puppet.err "Could not process report for %s: %s" % [client, detail]
                if Puppet[:trace]
                    puts detail.backtrace
                end
            end
        end

        private

        # Process the report using all of the existing hooks.
        def process(yaml)
            return if Puppet[:reports] == "none"

            # First convert the report to real objects
            begin
                report = YAML.load(yaml)
            rescue => detail
                Puppet.warning "Could not load report: %s" % detail
                return
            end

            # Used for those reports that accept yaml
            client = report.host

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
end

