require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:report, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Create, display, and submit reports"

  action(:submit) do
    when_invoked do |report, options|
      begin
        Puppet::Transaction::Report.terminus_class = :rest
        report.save
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Could not send report: #{detail}"
      end
    end
  end
end
