# frozen_string_literal: true

require_relative '../../puppet/reports'

Puppet::Reports.register_report(:log) do
  desc "Send all received logs to the local log destinations.  Usually
    the log destination is syslog."

  def process
    logs.each do |log|
      log.source = "//#{host}/#{log.source}"
      Puppet::Util::Log.newmessage(log)
    end
  end
end
