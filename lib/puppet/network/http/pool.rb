require 'sync'

class Puppet::Network::HTTP::Pool
  FIFTEEN_SECONDS = 15

  def initialize(keepalive_timeout = FIFTEEN_SECONDS)
    @pool_mutex = Mutex.new
    @pool = {}
    @keepalive_timeout = keepalive_timeout
  end

  def take_connection(site)
    @pool_mutex.synchronize do
      now = Time.now

      sessions = @pool[site]
      if sessions
        sessions.each_with_index do |session, idx|
          # possible optimzation, since keepalive is immutable,
          # connections will be sorted in mru order, and their
          # keepalive timeout will be increasing order. So as
          # soon as we hit an expired connection, we know
          # all that follow are expired too.
          if session.expired?(now)
            Puppet.debug("Closing expired connection for #{site}")
            begin
              session.connection.close
            rescue => detail
              Puppet.log_exception(detail, "Failed to close session for #{site}: #{detail}")
            end
          else
            session = sessions.slice!(idx)
            Puppet.debug("Using cached connection for #{site}")
            return session.connection
          end
        end
      end
    end

    Puppet.debug("Creating new connection for #{site}")
    Puppet::Network::HttpPool.http_instance(site.host, site.port, site.scheme == 'https', true)
  end

  def add_connection(site, connection)
    @pool_mutex.synchronize do
      sessions = @pool[site]

      if sessions.nil?
        sessions = []
        @pool[site] = sessions
      end

      # MRU
      expiration = Time.now + @keepalive_timeout
      session = Puppet::Network::HTTP::Session.new(connection, expiration)
      Puppet.debug("Caching connection for #{site}")
      sessions.unshift(session)
    end
  end

  def connection_count
    count = 0
    @pool_mutex.synchronize do
      @pool.each_pair do |site, sessions|
        count += sessions.count
      end
    end
    count
  end

  def close
    @pool_mutex.synchronize do
      @pool.each_pair do |site, sessions|
        sessions.each do |session|
          Puppet.debug("Closing connection for #{site}")
          session.connection.close
        end
      end
      @pool.clear
    end
  end
end
