require 'puppet/util/instance_loader'

# This class is an implementation of a simple mechanism for loading and returning reports.
# The intent is that a user registers a report by calling {register_report} and providing a code
# block that performs setup, and defines a method called `process`. The setup, and the `process` method
# are called in the context where `self` is an instance of {Puppet::Transaction::Report} which provides the actual
# data for the report via its methods.
#
# @example Minimal scaffolding for a report...
#   Puppet::Reports::.register_report(:myreport) do
#     # do setup here
#     def process
#       if self.status == 'failed'
#         msg = "failed puppet run for #{self.host} #{self.status}"
#         . . .
#       else
#         . . .
#       end
#     end
#   end
#
# Required configuration:
# --
# * A .rb file that defines a new report should be placed in the master's directory `lib/puppet/reports`
# * The `puppet.conf` file must have `report = true` in the `[agent]` section
#
# @see Puppet::Transaction::Report
# @api public
#
class Puppet::Reports
  extend Puppet::Util::ClassGen
  extend Puppet::Util::InstanceLoader

  # Set up autoloading and retrieving of reports.
  instance_load :report, 'puppet/reports'

  class << self
    # @api private
    attr_reader :hooks
  end

  # Adds a new report type.
  # The block should contain setup, and define a method with the name `process`. The `process` method is
  # called when the report is executed; the `process` method has access to report data via methods available
  # in its context where `self` is an instance of {Puppet::Transaction::Report}.
  #
  # For an example, see the overview of this class.
  #
  # @param name [Symbol] the name of the report (do not use whitespace in the name).
  # @param options [Hash] a hash of options
  # @option options [Boolean] :useyaml whether yaml should be used or not
  # @todo Uncertain what the options :useyaml really does; "whether yaml should be used or not", used where/how?
  #
  def self.register_report(name, options = {}, &block)
    name = name.intern

    mod = genmodule(name,
                    :extend    => Puppet::Util::Docs,
                    :hash      => instance_hash(:report),
                    :overwrite => true,
                    :block     => block)

    mod.useyaml = true if options[:useyaml]

    mod.send(:define_method, :report_name) do
      name
    end
  end

  # Collects the docs for all reports.
  # @api private
  def self.reportdocs
    docs = ""

    # Use this method so they all get loaded
    instance_loader(:report).loadall
    loaded_instances(:report).sort { |a,b| a.to_s <=> b.to_s }.each do |name|
      mod = self.report(name)
      docs << "#{name}\n#{"-" * name.to_s.length}\n"

      docs << Puppet::Util::Docs.scrub(mod.doc) << "\n\n"
    end

    docs
  end

  # Lists each of the reports.
  # @api private
  def self.reports
    instance_loader(:report).loadall
    loaded_instances(:report)
  end
end
