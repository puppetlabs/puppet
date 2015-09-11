require 'puppet/reports'

report = Puppet::Util::Reference.newreference :report, :doc => "All available transaction reports" do
  Puppet::Reports.reportdocs
end

report.header = "
Puppet can generate a report after applying a catalog. This report includes
events, log messages, resource statuses, and metrics and metadata about the run.
Puppet agent sends its report to a Puppet master server, and Puppet apply
processes its own reports.

Puppet master and Puppet apply will handle every report with a set of report
processors, configurable with the `reports` setting in puppet.conf. This page
documents the built-in report processors.

See [About Reporting](https://docs.puppetlabs.com/puppet/latest/reference/reporting_about.html)
for more details.

"
