#! /usr/bin/env ruby
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

  let(:verify) do
    stub('verify', :setup_connection => nil)
  end

  def create_pool
    Puppet::Network::HTTP::Pool.new
  end

  def create_pool_with_connections(site, *connections)
    pool = Puppet::Network::HTTP::Pool.new
    connections.each do |conn|
      pool.release(site, conn)
    end
    pool
  end

  def create_pool_with_expired_connections(site, *connections)
    # setting keepalive timeout to -1 ensures any newly added
    # connections have already expired
    pool = Puppet::Network::HTTP::Pool.new(-1)
    connections.each do |conn|
      pool.release(site, conn)
    end
    pool
  end

  def create_connection(site)
    stub(site.addr, :started? => false, :start => nil, :finish => nil, :use_ssl? => true, :verify_mode => OpenSSL::SSL::VERIFY_PEER)
  end

  context 'when yielding a connection' do
    it 'yields a connection' do
      conn = create_connection(site)
      pool = create_pool_with_connections(site, conn)

      expect { |b|
        pool.with_connection(site, verify, &b)
      }.to yield_with_args(conn)
    end

    it 'returns the connection to the pool' do
      conn = create_connection(site)
      pool = create_pool
      pool.release(site, conn)

      pool.with_connection(site, verify) { |c| }

      expect(pool.pool[site].first.connection).to eq(conn)
    end

    it 'can yield multiple connections to the same site' do
      lru_conn = create_connection(site)
      mru_conn = create_connection(site)
      pool = create_pool_with_connections(site, lru_conn, mru_conn)

      pool.with_connection(site, verify) do |a|
        expect(a).to eq(mru_conn)

        pool.with_connection(site, verify) do |b|
          expect(b).to eq(lru_conn)
        end
      end
    end

    it 'propagates exceptions' do
      conn = create_connection(site)
      pool = create_pool
      pool.release(site, conn)

      expect {
        pool.with_connection(site, verify) do |c|
          raise IOError, 'connection reset'
        end
      }.to raise_error(IOError, 'connection reset')
    end

    it 'does not re-cache connections when an error occurs' do
      # we're not distinguishing between network errors that would
      # suggest we close the socket, and other errors
      conn = create_connection(site)
      pool = create_pool
      pool.release(site, conn)

      pool.expects(:release).with(site, conn).never

      pool.with_connection(site, verify) do |c|
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
        conn.expects(:use_ssl?).returns(false)

        pool = create_pool_with_connections(site, conn)
        pool.expects(:release).with(site, conn)

        pool.with_connection(site, verify) {|c| }
      end

      it 'releases secure HTTPS connections' do
        conn = create_connection(site)
        conn.expects(:use_ssl?).returns(true)
        conn.expects(:verify_mode).returns(OpenSSL::SSL::VERIFY_PEER)

        pool = create_pool_with_connections(site, conn)
        pool.expects(:release).with(site, conn)

        pool.with_connection(site, verify) {|c| }
      end

      it 'closes insecure HTTPS connections' do
        conn = create_connection(site)
        conn.expects(:use_ssl?).returns(true)
        conn.expects(:verify_mode).returns(OpenSSL::SSL::VERIFY_NONE)

        pool = create_pool_with_connections(site, conn)

        pool.expects(:release).with(site, conn).never

        pool.with_connection(site, verify) {|c| }
      end
    end
  end

  context 'when borrowing' do
    it 'returns a new connection if the pool is empty' do
      conn = create_connection(site)
      pool = create_pool
      pool.factory.expects(:create_connection).with(site).returns(conn)
      pool.expects(:setsockopts)

      expect(pool.borrow(site, verify)).to eq(conn)
    end

    it 'returns a matching connection' do
      conn = create_connection(site)
      pool = create_pool_with_connections(site, conn)

      pool.factory.expects(:create_connection).never

      expect(pool.borrow(site, verify)).to eq(conn)
    end

    it 'returns a new connection if there are no matching sites' do
      different_conn = create_connection(different_site)
      pool = create_pool_with_connections(different_site, different_conn)

      conn = create_connection(site)
      pool.factory.expects(:create_connection).with(site).returns(conn)
      pool.expects(:setsockopts)

      expect(pool.borrow(site, verify)).to eq(conn)
    end

    it 'returns started connections' do
      conn = create_connection(site)
      conn.expects(:start)

      pool = create_pool
      pool.factory.expects(:create_connection).with(site).returns(conn)
      pool.expects(:setsockopts)

      expect(pool.borrow(site, verify)).to eq(conn)
    end

    it "doesn't start a cached connection" do
      conn = create_connection(site)
      conn.expects(:start).never

      pool = create_pool_with_connections(site, conn)
      pool.borrow(site, verify)
    end

    it 'returns the most recently used connection from the pool' do
      least_recently_used = create_connection(site)
      most_recently_used = create_connection(site)

      pool = create_pool_with_connections(site, least_recently_used, most_recently_used)
      expect(pool.borrow(site, verify)).to eq(most_recently_used)
    end

    it 'finishes expired connections' do
      conn = create_connection(site)
      conn.expects(:finish)

      pool = create_pool_with_expired_connections(site, conn)
      pool.factory.expects(:create_connection => stub('conn', :start => nil))
      pool.expects(:setsockopts)

      pool.borrow(site, verify)
    end

    it 'logs an exception if it fails to close an expired connection' do
      Puppet.expects(:log_exception).with(is_a(IOError), "Failed to close connection for #{site}: read timeout")

      conn = create_connection(site)
      conn.expects(:finish).raises(IOError, 'read timeout')

      pool = create_pool_with_expired_connections(site, conn)
      pool.factory.expects(:create_connection => stub('open_conn', :start => nil))
      pool.expects(:setsockopts)

      pool.borrow(site, verify)
    end
  end

  context 'when releasing a connection' do
    it 'adds the connection to an empty pool' do
      conn = create_connection(site)

      pool = create_pool
      pool.release(site, conn)

      expect(pool.pool[site].first.connection).to eq(conn)
    end

    it 'adds the connection to a pool with a connection for the same site' do
      pool = create_pool
      pool.release(site, create_connection(site))
      pool.release(site, create_connection(site))

      expect(pool.pool[site].count).to eq(2)
    end

    it 'adds the connection to a pool with a connection for a different site' do
      pool = create_pool
      pool.release(site, create_connection(site))
      pool.release(different_site, create_connection(different_site))

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
      conn.expects(:finish)

      pool = create_pool_with_connections(site, conn)
      pool.close
    end
  end
end
