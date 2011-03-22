require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:report) do
  action(:submit) do
    invoke do |report|
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
