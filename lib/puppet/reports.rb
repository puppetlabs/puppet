require 'puppet/util/instance_loader'

# A simple mechanism for loading and returning reports.
class Puppet::Reports
    extend Puppet::Util::ClassGen
    extend Puppet::Util::InstanceLoader

    # Set up autoloading and retrieving of reports.
    instance_load :report, 'puppet/reports'

    class << self
        attr_reader :hooks
    end

    # Add a new report type.
    def self.register_report(name, options = {}, &block)
        name = symbolize(name)

        mod = genmodule(name, :extend => Puppet::Util::Docs, :hash => instance_hash(:report), :block => block)

        if options[:useyaml]
            mod.useyaml = true
        end

        mod.send(:define_method, :report_name) do
            name
        end
    end

    # Collect the docs for all of our reports.
    def self.reportdocs
        docs = ""

        # Use this method so they all get loaded
        instance_loader(:report).loadall
        loaded_instances(:report).sort { |a,b| a.to_s <=> b.to_s }.each do |name|
            mod = self.report(name)
            docs += "%s\n%s\n" % [name, "-" * name.to_s.length]

            docs += Puppet::Util::Docs.scrub(mod.doc) + "\n\n"
        end

        docs
    end

    # List each of the reports.
    def self.reports
        instance_loader(:report).loadall
        loaded_instances(:report)
    end
end
