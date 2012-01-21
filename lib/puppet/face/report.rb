require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:report, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Create, display, and submit reports."

  get_action(:find).summary "Invalid for this face."
  get_action(:search).summary "Invalid for this face."
  get_action(:destroy).summary "Invalid for this face."
  save = get_action(:save)
  save.summary "API only: submit a report."
  save.arguments "<report>"
  save.returns "Nothing."
  save.examples <<-'EOT'
    From the implementation of `puppet report submit` (API example):

        begin
          Puppet::Transaction::Report.indirection.terminus_class = :rest
          Puppet::Face[:report, "0.0.1"].save(report)
          Puppet.notice "Uploaded report for #{report.name}"
        rescue => detail
          puts detail.backtrace if Puppet[:trace]
          Puppet.err "Could not send report: #{detail}"
        end
  EOT

  action(:submit) do
    summary "API only: submit a report with error handling."
    description <<-'EOT'
      API only: Submits a report to the puppet master. This action is
      essentially a shortcut and wrapper for the `save` action with the `rest`
      terminus, and provides additional details in the event of a failure.
    EOT
    arguments "<report>"
    examples <<-'EOT'
      From secret_agent.rb (API example):

          # ...
          report  = Puppet::Face[:catalog, '0.0.1'].apply
          Puppet::Face[:report, '0.0.1'].submit(report)
          return report
    EOT
    when_invoked do |report, options|
      begin
        Puppet::Transaction::Report.indirection.terminus_class = :rest
        Puppet::Face[:report, "0.0.1"].save(report)
        Puppet.notice "Uploaded report for #{report.name}"
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Could not send report: #{detail}"
      end
    end
  end
end
