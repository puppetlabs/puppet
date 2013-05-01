require 'puppet/network/http'
require 'puppet/network/http/webrick'

#
# @api private
class Puppet::Network::Server
  attr_reader :address, :port

  def initialize(address, port)
    @port = port
    @address = address
    @http_server = Puppet::Network::HTTP::WEBrick.new

    @listening = false

    # Make sure we have all of the directories we need to function.
    Puppet.settings.use(:main, :ssl, :application)
  end

  def listening?
    @listening
  end

  def start
    raise "Cannot listen -- already listening." if listening?
    @listening = true
    @http_server.listen(address, port)
  end

  def stop
    raise "Cannot unlisten -- not currently listening." unless listening?
    @http_server.unlisten
    @listening = false
  end

  def wait_for_shutdown
    @http_server.wait_for_shutdown
  end
end
