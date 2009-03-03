require 'puppet/reports'

report = Puppet::Util::Reference.newreference :report, :doc => "All available transaction reports" do
    Puppet::Reports.reportdocs
end

report.header = "
Puppet clients can report back to the server after each transaction.  This
transaction report is sent as a YAML dump of the
``Puppet::Transaction::Report`` class and includes every log message that was
generated during the transaction along with as many metrics as Puppet knows how
to collect.  See `ReportsAndReporting Reports and Reporting`:trac:
for more information on how to use reports.

Currently, clients default to not sending in reports; you can enable reporting
by setting the ``report`` parameter to true.

To use a report, set the ``reports`` parameter on the server; multiple
reports must be comma-separated.  You can also specify ``none`` to disable
reports entirely.

Puppet provides multiple report handlers that will process client reports:

"
