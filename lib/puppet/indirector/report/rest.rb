require 'puppet/indirector/rest'

class Puppet::Transaction::Report::Rest < Puppet::Indirector::REST
  desc "Get server report over HTTP via REST."
  use_server_setting(:report_server)
  use_port_setting(:report_port)
  use_srv_service(:report)

  private

  def deserialize_save(content_type, body)
    format = Puppet::Network::FormatHandler.format_for(content_type)
    format.intern(Array, body)
  end
end
