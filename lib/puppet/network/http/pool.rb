class Puppet::Network::HTTP::Pool
  FIFTEEN_SECONDS = 15

  def initialize(keepalive_timeout = FIFTEEN_SECONDS)
    @pool = {}
    @keepalive_timeout = keepalive_timeout
  end

  def with_connection(site, factory, &block)
    reuse = true

    connection = borrow(site, factory)
    begin
      yield connection
    rescue => detail
      reuse = false
      close_connection(site, connection)
      raise detail
    ensure
      release(site, connection) if reuse
    end
  end

  def close
    @pool.each_pair do |site, sessions|
      sessions.each do |session|
        close_connection(site, session.connection)
      end
    end
    @pool.clear
  end

  # api private

  def pool
    @pool
  end

  def close_connection(site, connection)
    Puppet.debug("Closing connection for #{site}")
    connection.finish
  rescue => detail
    Puppet.log_exception(detail, "Failed to close connection for #{site}: #{detail}")
  end

  def borrow(site, factory)
    @pool[site] = active_sessions(site)
    session = @pool[site].shift
    if session
      Puppet.debug("Using cached connection for #{site}")
      session.connection
    else
      Puppet.debug("Starting connection for #{site}")
      connection = factory.create_connection(site)
      connection.start
      connection
    end
  end

  def release(site, connection)
    expiration = Time.now + @keepalive_timeout
    session = Puppet::Network::HTTP::Session.new(connection, expiration)
    Puppet.debug("Caching connection for #{site}")

    sessions = @pool[site]
    if sessions
      sessions.unshift(session)
    else
      @pool[site] = [session]
    end
  end

  def active_sessions(site)
    now = Time.now

    sessions = @pool[site] || []
    sessions.select do |session|
      if session.expired?(now)
        close_connection(site, session.connection)
        false
      else
        true
      end
    end
  end
end
