require 'puppet/reports'

Puppet::Reports.register_report(:log) do
    desc "Send all received logs to the local log destinations.  Usually
        the log destination is syslog."

    def process
        self.logs.each do |log|
            Puppet::Util::Log.newmessage(log)
        end
    end
end

