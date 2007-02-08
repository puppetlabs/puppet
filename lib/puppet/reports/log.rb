require 'puppet'

Puppet::Network::Server::Report.newreport(:log) do
    desc "Send all received logs to the local log destinations."

    def process
        self.logs.each do |log|
            Puppet::Util::Log.newmessage(log)
        end
    end
end

# $Id$
