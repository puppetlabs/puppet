require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:report, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Create, display, and submit reports"
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `processor`
    * `rest`
    * `yaml`
  EOT

  get_action(:find).summary "Invalid for this face."
  get_action(:search).summary "Invalid for this face."
  get_action(:destroy).summary "Invalid for this face."
  save = get_action(:save)
  save.summary "Submit a report."
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
    summary "Submit a report object to the puppet master"
    description <<-'EOT'
      This action is essentially a shortcut and wrapper for the `save` action
      with the `rest` terminus, which provides additional details in the
      event of a report submission failure. It is not intended for use from
      a command line.
    EOT
    examples <<-'EOT'
      From secret_agent.rb:

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
