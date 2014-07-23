class Puppet::Network::HTTP::Pool
  FIFTEEN_SECONDS = 15

  attr_reader :factory

  def initialize(keepalive_timeout = FIFTEEN_SECONDS)
    @pool = {}
    @factory = Puppet::Network::HTTP::Factory.new
    @keepalive_timeout = keepalive_timeout
  end

  def with_connection(site, verify, &block)
    reuse = true

    http = borrow(site, verify)
    begin
      yield http
    rescue => detail
      reuse = false
      close_connection(site, http)
      raise detail
    ensure
      release(site, http) if reuse
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

  def close_connection(site, http)
    Puppet.debug("Closing connection for #{site}")
    http.finish
  rescue => detail
    Puppet.log_exception(detail, "Failed to close connection for #{site}: #{detail}")
  end

  def borrow(site, verify)
    @pool[site] = active_sessions(site)
    session = @pool[site].shift
    if session
      Puppet.debug("Using cached connection for #{site}")
      session.connection
    else
      http = @factory.create_connection(site)
      verify.setup_connection(http)

      Puppet.debug("Starting connection for #{site}")
      http.start
      http
    end
  end

  def release(site, http)
    expiration = Time.now + @keepalive_timeout
    session = Puppet::Network::HTTP::Session.new(http, expiration)
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
