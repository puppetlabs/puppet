require 'spec_helper'

require 'openssl'
require 'puppet/network/http'
require 'puppet/network/http_pool'

describe Puppet::Network::HTTP::Pool do
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  let(:site) do
    Puppet::Network::HTTP::Site.new('https', 'rubygems.org', 443)
  end

  let(:different_site) do
    Puppet::Network::HTTP::Site.new('https', 'github.com', 443)
  end

  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:verifier) do
    v = Puppet::SSL::Verifier.new(site.host, ssl_context)
    allow(v).to receive(:setup_connection)
    v
  end

  def create_pool
    Puppet::Network::HTTP::Pool.new
  end

  def create_pool_with_connections(site, *connections)
    pool = Puppet::Network::HTTP::Pool.new
    connections.each do |conn|
      pool.release(site, verifier, conn)
    end
    pool
  end

  def create_pool_with_expired_connections(site, *connections)
    # setting keepalive timeout to -1 ensures any newly added
    # connections have already expired
    pool = Puppet::Network::HTTP::Pool.new(-1)
    connections.each do |conn|
      pool.release(site, verifier, conn)
    end
    pool
  end

  def create_connection(site)
    double(site.addr, :started? => false, :start => nil, :finish => nil, :use_ssl? => true, :verify_mode => OpenSSL::SSL::VERIFY_PEER)
  end

  context 'when yielding a connection' do
    it 'yields a connection' do
      conn = create_connection(site)
      pool = create_pool_with_connections(site, conn)

      expect { |b|
        pool.with_connection(site, verifier, &b)
      }.to yield_with_args(conn)
    end

    it 'returns the connection to the pool' do
      conn = create_connection(site)
      expect(conn).to receive(:started?).and_return(true)

      pool = create_pool
      pool.release(site, verifier, conn)

      pool.with_connection(site, verifier) { |c| }

      expect(pool.pool[site].first.connection).to eq(conn)
    end

    it 'can yield multiple connections to the same site' do
      lru_conn = create_connection(site)
      mru_conn = create_connection(site)
      pool = create_pool_with_connections(site, lru_conn, mru_conn)

      pool.with_connection(site, verifier) do |a|
        expect(a).to eq(mru_conn)

        pool.with_connection(site, verifier) do |b|
          expect(b).to eq(lru_conn)
        end
      end
    end

    it 'propagates exceptions' do
      conn = create_connection(site)
      pool = create_pool
      pool.release(site, verifier, conn)

      expect {
        pool.with_connection(site, verifier) do |c|
          raise IOError, 'connection reset'
        end
      }.to raise_error(IOError, 'connection reset')
    end

    it 'does not re-cache connections when an error occurs' do
      # we're not distinguishing between network errors that would
      # suggest we close the socket, and other errors
      conn = create_connection(site)
      pool = create_pool
      pool.release(site, verifier, conn)

      expect(pool).not_to receive(:release).with(site, verifier, conn)

      pool.with_connection(site, verifier) do |c|
        raise IOError, 'connection reset'
      end rescue nil
    end

    it 'sets keepalive bit on network socket' do
      pool = create_pool
      s = Socket.new(Socket::PF_INET, Socket::SOCK_STREAM)
      pool.setsockopts(Net::BufferedIO.new(s))

      # On windows, Socket.getsockopt() doesn't return exactly the same data
      # as an equivalent Socket::Option.new() statement, so we strip off the
      # unrelevant bits only on this platform.
      #
      # To make sure we're not voiding the test case by doing this, we check
      # both with and without the keepalive bit set.
      #
      # This workaround can be removed once all the ruby versions we care about
      # have the patch from https://bugs.ruby-lang.org/issues/11958 applied.
      #
      if Puppet::Util::Platform.windows?
        keepalive   = Socket::Option.bool(:INET, :SOCKET, :KEEPALIVE, true).data[0]
        nokeepalive = Socket::Option.bool(:INET, :SOCKET, :KEEPALIVE, false).data[0]
        expect(s.getsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE).data).to eq(keepalive)
        expect(s.getsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE).data).to_not eq(nokeepalive)
      else
        expect(s.getsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE).bool).to eq(true)
      end
    end

    context 'when releasing connections' do
      it 'releases HTTP connections' do
        conn = create_connection(site)
        expect(conn).to receive(:use_ssl?).and_return(false)
        expect(conn).to receive(:started?).and_return(true)

        pool = create_pool_with_connections(site, conn)
        expect(pool).to receive(:release).with(site, verifier, conn)

        pool.with_connection(site, verifier) {|c| }
      end

      it 'releases secure HTTPS connections' do
        conn = create_connection(site)
        expect(conn).to receive(:use_ssl?).and_return(true)
        expect(conn).to receive(:verify_mode).and_return(OpenSSL::SSL::VERIFY_PEER)
        expect(conn).to receive(:started?).and_return(true)

        pool = create_pool_with_connections(site, conn)
        expect(pool).to receive(:release).with(site, verifier, conn)

        pool.with_connection(site, verifier) {|c| }
      end

      it 'closes insecure HTTPS connections' do
        conn = create_connection(site)
        expect(conn).to receive(:use_ssl?).and_return(true)
        expect(conn).to receive(:verify_mode).and_return(OpenSSL::SSL::VERIFY_NONE)

        pool = create_pool_with_connections(site, conn)

        expect(pool).not_to receive(:release).with(site, verifier, conn)

        pool.with_connection(site, verifier) {|c| }
      end

      it "doesn't add a closed  connection back to the pool" do
        conn = create_connection(site)
        expect(conn).to receive(:use_ssl?).and_return(true)
        expect(conn).to receive(:verify_mode).and_return(OpenSSL::SSL::VERIFY_PEER)

        pool = create_pool_with_connections(site, conn)

        pool.with_connection(site, verifier) {|c| c.finish}

        expect(pool.pool[site]).to be_empty
      end
    end
  end

  context 'when borrowing' do
    it 'returns a new connection if the pool is empty' do
      conn = create_connection(site)
      pool = create_pool
      expect(pool.factory).to receive(:create_connection).with(site).and_return(conn)
      expect(pool).to receive(:setsockopts)

      expect(pool.borrow(site, verifier)).to eq(conn)
    end

    it 'returns a matching connection' do
      conn = create_connection(site)
      pool = create_pool_with_connections(site, conn)

      expect(pool.factory).not_to receive(:create_connection)

      expect(pool.borrow(site, verifier)).to eq(conn)
    end

    it 'returns a new connection if there are no matching sites' do
      different_conn = create_connection(different_site)
      pool = create_pool_with_connections(different_site, different_conn)

      conn = create_connection(site)
      expect(pool.factory).to receive(:create_connection).with(site).and_return(conn)
      expect(pool).to receive(:setsockopts)

      expect(pool.borrow(site, verifier)).to eq(conn)
    end

    it 'returns a new connection if the ssl contexts are different' do
      old_conn = create_connection(site)
      pool = create_pool_with_connections(site, old_conn)
      allow(pool).to receive(:setsockopts)

      new_conn = create_connection(site)
      allow(pool.factory).to receive(:create_connection).with(site).and_return(new_conn)

      new_verifier = Puppet::SSL::Verifier.new(site.host, Puppet::SSL::SSLContext.new)
      allow(new_verifier).to receive(:setup_connection)

      # 'equal' tests that it's the same object
      expect(pool.borrow(site, new_verifier)).to eq(new_conn)
    end

    it 'returns a cached connection if the ssl contexts are the same' do
      old_conn = create_connection(site)
      pool = create_pool_with_connections(site, old_conn)
      allow(pool).to receive(:setsockopts)

      expect(pool.factory).not_to receive(:create_connection)

      # 'equal' tests that it's the same object
      new_verifier = Puppet::SSL::Verifier.new(site.host, ssl_context)
      expect(pool.borrow(site, new_verifier)).to equal(old_conn)
    end

    it 'returns started connections' do
      conn = create_connection(site)
      expect(conn).to receive(:start)

      pool = create_pool
      expect(pool.factory).to receive(:create_connection).with(site).and_return(conn)
      expect(pool).to receive(:setsockopts)

      expect(pool.borrow(site, verifier)).to eq(conn)
    end

    it "doesn't start a cached connection" do
      conn = create_connection(site)
      expect(conn).not_to receive(:start)

      pool = create_pool_with_connections(site, conn)
      pool.borrow(site, verifier)
    end

    it 'returns the most recently used connection from the pool' do
      least_recently_used = create_connection(site)
      most_recently_used = create_connection(site)

      pool = create_pool_with_connections(site, least_recently_used, most_recently_used)
      expect(pool.borrow(site, verifier)).to eq(most_recently_used)
    end

    it 'finishes expired connections' do
      conn = create_connection(site)

      expect(conn).to receive(:started?).and_return(true)
      expect(conn).to receive(:finish)

      pool = create_pool_with_expired_connections(site, conn)
      expect(pool.factory).to receive(:create_connection).and_return(double('conn', :start => nil))
      expect(pool).to receive(:setsockopts)

      pool.borrow(site, verifier)
    end

    it 'logs an exception if it fails to close an expired connection' do
      expect(Puppet).to receive(:log_exception).with(be_a(IOError), "Failed to close connection for #{site}: read timeout")

      conn = create_connection(site)
      expect(conn).to receive(:started?).and_return(true)
      expect(conn).to receive(:finish).and_raise(IOError, 'read timeout')

      pool = create_pool_with_expired_connections(site, conn)
      expect(pool.factory).to receive(:create_connection).and_return(double('open_conn', :start => nil))
      expect(pool).to receive(:setsockopts)

      pool.borrow(site, verifier)
    end
  end

  context 'when releasing a connection' do
    it 'adds the connection to an empty pool' do
      conn = create_connection(site)

      pool = create_pool
      pool.release(site, verifier, conn)

      expect(pool.pool[site].first.connection).to eq(conn)
    end

    it 'adds the connection to a pool with a connection for the same site' do
      pool = create_pool
      pool.release(site, verifier, create_connection(site))
      pool.release(site, verifier, create_connection(site))

      expect(pool.pool[site].count).to eq(2)
    end

    it 'adds the connection to a pool with a connection for a different site' do
      pool = create_pool
      pool.release(site, verifier, create_connection(site))
      pool.release(different_site, verifier, create_connection(different_site))

      expect(pool.pool[site].count).to eq(1)
      expect(pool.pool[different_site].count).to eq(1)
    end
  end

  context 'when closing' do
    it 'clears the pool' do
      pool = create_pool
      pool.close

      expect(pool.pool).to be_empty
    end

    it 'closes all cached connections' do
      conn = create_connection(site)

      expect(conn).to receive(:started?).and_return(true)
      expect(conn).to receive(:finish)

      pool = create_pool_with_connections(site, conn)
      pool.close
    end

    it 'allows a connection to be closed multiple times safely' do
      conn = create_connection(site)
      expect(conn).to receive(:started?).and_return(true)
      pool = create_pool_with_connections(site, conn)
      expect(pool.close_connection(site, conn)).to eq(true)
      expect(pool.close_connection(site, conn)).to eq(false)
   end
  end
end
