require 'puppet/indirector/rest'

class Puppet::Transaction::Report::Rest < Puppet::Indirector::REST
    desc "Get server report over HTTP via REST."
    use_server_setting(:report_server)
    use_port_setting(:report_port)
end
