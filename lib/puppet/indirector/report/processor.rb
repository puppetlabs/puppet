require 'puppet/transaction/report'
require 'puppet/indirector/code'
require 'puppet/reports'

class Puppet::Transaction::Report::Processor < Puppet::Indirector::Code
  desc "Puppet's report processor.  Processes the report with each of
    the report types listed in the 'reports' setting."

  def initialize
    Puppet.settings.use(:main, :reporting, :metrics)
  end

  def save(request)
    process(request.instance)
  end

  def destroy(request)
    processors do |mod|
      mod.destroy(request.key) if mod.respond_to?(:destroy)
    end
  end

  private

  # Process the report with each of the configured report types.
  # LAK:NOTE This isn't necessarily the best design, but it's backward
  # compatible and that's good enough for now.
  def process(report)
    Puppet.debug "Received report to process from #{report.host}"
    processors do |mod|
      Puppet.debug "Processing report from #{report.host} with processor #{mod}"
      # We have to use a dup because we're including a module in the
      # report.
      newrep = report.dup
      begin
        newrep.extend(mod)
        newrep.process
      rescue => detail
        Puppet.log_exception(detail, _("Report %{report} failed: %{detail}") % { report: name, detail: detail })
      end
    end
  end

  # Handle the parsing of the reports attribute.
  def reports
    Puppet[:reports].gsub(/(^\s+)|(\s+$)/, '').split(/\s*,\s*/)
  end

  def processors(&blk)
    return [] if Puppet[:reports] == "none"
    reports.each do |name|
      if mod = Puppet::Reports.report(name)
        yield(mod)
      else
        Puppet.warning _("No report named '%{name}'") % { name: name }
      end
    end
  end
end
