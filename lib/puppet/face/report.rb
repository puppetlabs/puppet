require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:report, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Create, display, and submit reports.")

  save = get_action(:save)
  save.summary _("API only: submit a report.")
  save.arguments _("<report>")
  save.returns _("Nothing.")
  save.examples <<-'EOT'
    From the implementation of `puppet report submit` (API example):

        begin
          Puppet::Transaction::Report.indirection.terminus_class = :rest
          Puppet::Face[:report, "0.0.1"].save(report)
          Puppet.notice "Uploaded report for #{report.name}"
        rescue => detail
          Puppet.log_exception(detail, "Could not send report: #{detail}")
        end
  EOT

  action(:submit) do
    summary _("API only: submit a report with error handling.")
    description <<-'EOT'
      API only: Submits a report to the puppet master. This action is
      essentially a shortcut and wrapper for the `save` action with the `rest`
      terminus, and provides additional details in the event of a failure.
    EOT
    arguments _("<report>")
    examples <<-'EOT'
      API example:

          # ...
          report  = Puppet::Face[:catalog, '0.0.1'].apply
          Puppet::Face[:report, '0.0.1'].submit(report)
          return report
    EOT
    when_invoked do |report, options|
      begin
        Puppet::Transaction::Report.indirection.terminus_class = :rest
        Puppet::Face[:report, "0.0.1"].save(report)
        Puppet.notice _("Uploaded report for %{name}") % { name: report.name }
      rescue => detail
        Puppet.log_exception(detail, _("Could not send report: %{detail}") % { detail: detail })
      end
    end
  end
  deactivate_action(:find)
  deactivate_action(:search)
  deactivate_action(:destroy)
end
