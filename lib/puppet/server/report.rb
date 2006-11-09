module Puppet
class Server
    # A simple server for triggering a new run on a Puppet client.
    class Report < Handler
        class << self
            include Puppet::Util::ClassGen
        end

        module ReportBase
            include Puppet::Util::Docs
            attr_writer :useyaml

            def useyaml?
                if defined? @useyaml
                    @useyaml
                else
                    false
                end
            end
        end

        @interface = XMLRPC::Service::Interface.new("puppetreports") { |iface|
            iface.add_method("string report(array)")
        }

        Puppet.setdefaults(:reporting,
            :reports => ["store",
                "The list of reports to generate.  All reports are looked for
                in puppet/reports/<name>.rb, and multiple report names should be
                comma-separated (whitespace is okay)."
            ]
        )

        @reports = {}
        @reportloader = Puppet::Autoload.new(self, "puppet/reports")

        class << self
            attr_reader :hooks
        end

        # Add a new report type.
        def self.newreport(name, options = {}, &block)
            name = symbolize(name)

            mod = genmodule(name, :extend => ReportBase, :hash => @reports, :block => block)

            if options[:useyaml]
                mod.useyaml = true
            end

            mod.send(:define_method, :report_name) do
                name
            end
        end

        # Load a report.
        def self.report(name)
            name = name.intern if name.is_a? String
            unless @reports.include? name
                if @reportloader.load(name)
                    unless @reports.include? name
                        Puppet.warning(
                            "Loaded report file for %s but report was not defined" %
                            name
                        )
                        return nil
                    end
                else
                    return nil
                end
            end
            @reports[symbolize(name)]
        end

        def self.reportdocs
            docs = %{Puppet clients can report back to the server after each
transaction.  This transaction report is sent as a YAML dump and includes every
log message that was generated during the transaction along with as many metrics
as Puppet knows how to collect.

Currently, clients default to not sending in reports; you can enable reporting
by setting the ``report`` parameter to true.

To use a report, set the ``reports`` parameter on the server; multiple
reports must be comma-separated.

Puppet provides multiple report handlers that will process client reports:

}
            # Use this method so they all get loaded
            reports.sort { |a,b| a.to_s <=> b.to_s }.each do |name|
                mod = self.report(name)
                docs += "## %s\n\n" % name

                docs += Puppet::Util::Docs.scrub(mod.doc) + "\n\n"
            end

            docs
        end

        def self.reports
            @reportloader.loadall
            @reports.keys
        end

        def initialize(*args)
            super
            Puppet.config.use(:reporting)
            Puppet.config.use(:metrics)
        end

        # Accept a report from a client.
        def report(report, client = nil, clientip = nil)
            # Unescape the report
            unless @local
                report = CGI.unescape(report)
            end

            begin
                process(report)
            rescue => detail
                Puppet.err "Could not process report %s: %s" % [$1, detail]
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
                if mod = self.class.report(name)
                    Puppet.info "Processing report %s" % name

                    # We have to use a dup because we're including a module in the
                    # report.
                    newrep = report.dup
                    begin
                        newrep.extend(mod)
                        if mod.useyaml?
                            newrep.process(yaml)
                        else
                            newrep.process
                        end
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
            Puppet[:reports].gsub(/(^\s+)|(\s+$)/, '').split(/\s*,\s*/)
        end
    end
end
end

# $Id$
