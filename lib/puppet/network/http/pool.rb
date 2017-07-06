# A pool for persistent <tt>Net::HTTP</tt> connections. Connections are
# stored in the pool indexed by their {Puppet::Network::HTTP::Site Site}.
# Connections are borrowed from the pool, yielded to the caller, and
# released back into the pool. If a connection is expired, it will be
# closed either when a connection to that site is requested, or when
# the pool is closed. The pool can store multiple connections to the
# same site, and will be reused in MRU order.
#
# @api private
#
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
      if http.use_ssl? && http.verify_mode != OpenSSL::SSL::VERIFY_PEER
        reuse = false
      end

      yield http
    rescue => detail
      reuse = false
      raise detail
    ensure
      if reuse
        release(site, http)
      else
        close_connection(site, http)
      end
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

  # @api private
  def pool
    @pool
  end

  # Safely close a persistent connection.
  #
  # @api private
  def close_connection(site, http)
    Puppet.debug("Closing connection for #{site}")
    http.finish
  rescue => detail
    Puppet.log_exception(detail, "Failed to close connection for #{site}: #{detail}")
  end

  # Borrow and take ownership of a persistent connection. If a new
  # connection is created, it will be started prior to being returned.
  #
  # @api private
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
      setsockopts(http.instance_variable_get(:@socket))
      http
    end
  end

  # Set useful socket option(s) which lack from default settings in Net:HTTP
  #
  # @api private
  def setsockopts(netio)
    socket = netio.io
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
  end

  # Release a connection back into the pool.
  #
  # @api private
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

  # Returns an Array of sessions whose connections are not expired.
  #
  # @api private
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
