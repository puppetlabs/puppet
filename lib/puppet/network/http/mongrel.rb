require 'mongrel' if Puppet.features.mongrel?

require 'puppet/network/http/mongrel/rest'

class Puppet::Network::HTTP::Mongrel
  def initialize(args = {})
    @listening = false
  end

  def listen(args = {})
    raise ArgumentError, ":address must be specified." unless args[:address]
    raise ArgumentError, ":port must be specified." unless args[:port]
    raise "Mongrel server is already listening" if listening?

    @server = Mongrel::HttpServer.new(args[:address], args[:port])
    @server.register('/', Puppet::Network::HTTP::MongrelREST.new(:server => @server))

    @listening = true
    @server.run
  end

  def unlisten
    raise "Mongrel server is not listening" unless listening?
    @server.stop
    @server = nil
    @listening = false
  end

  def listening?
    @listening
  end
end
