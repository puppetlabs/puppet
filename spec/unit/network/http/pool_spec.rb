#! /usr/bin/env ruby
require 'spec_helper'

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
  let(:github_site) do
    Puppet::Network::HTTP::Site.new('https', 'github.com', 443)
  end

  def create_empty_pool
    Puppet::Network::HTTP::Pool.new
  end

  def create_pool_with_connection(site, connection)
    pool = Puppet::Network::HTTP::Pool.new
    pool.add_connection(site, connection)
    pool
  end

  def create_pool_with_expired_connections(site, *connections)
    # setting keepalive timeout to -1 ensures any newly added
    # connections have already expired
    pool = Puppet::Network::HTTP::Pool.new(-1)
    connections.each do |conn|
      pool.add_connection(site, conn)
    end
    pool
  end

  def create_connection(site)
    Puppet::Network::HttpPool.http_instance(site.host, site.port, site.scheme == 'https', false)
  end

  def expects_connection_for_site(site)
    Puppet::Network::HttpPool.expects(:http_instance).with(site.host, site.port, site.scheme == 'https', true)
  end

  context 'when taking a connection' do
    it 'returns a new connection if the pool is empty' do
      expects_connection_for_site(site)

      pool = create_empty_pool
      pool.take_connection(site)
    end

    it 'returns a new connection if there are no matching connections for that site' do
      connection = create_connection(site)
      pool = create_pool_with_connection(site, connection)

      expects_connection_for_site(github_site)

      pool.take_connection(github_site)
    end

    it 'takes a matching connection from the pool' do
      connection = create_connection(site)
      pool = create_pool_with_connection(site, connection)

      expect(pool.take_connection(site)).to eq(connection)
    end

    it 'takes the most recently used connection from the pool' do
      least_recently_used = create_connection(site)
      most_recently_used = create_connection(site)

      pool = create_empty_pool
      pool.add_connection(site, least_recently_used)
      pool.add_connection(site, most_recently_used)

      expect(pool.take_connection(site)).to eq(most_recently_used)
    end

    it 'closes all expired connections' do
      conn1 = create_connection(site)
      conn2 = create_connection(site)

      conn1.expects(:close)
      conn2.expects(:close)

      expects_connection_for_site(site)

      pool = create_pool_with_expired_connections(site, conn1, conn2)
      pool.take_connection(site)
    end

    it 'logs an exception if it fails to close an expired connection' do
      Puppet.expects(:log_exception).with(is_a(IOError), "Failed to close session for #{site}: read timeout")

      connection = create_connection(site)
      connection.expects(:close).raises(IOError, 'read timeout')

      pool = create_pool_with_expired_connections(site, connection)
      pool.take_connection(site)
    end
  end

  context 'when adding a connection' do
    it 'adds the connection to an empty pool' do
      connection = create_connection(site)
      pool = create_pool_with_connection(site, connection)

      expect(pool.connection_count).to eq(1)
    end

    it 'adds the connection to a pool with a connection for the same site' do
      conn1 = create_connection(site)
      conn2 = create_connection(site)

      pool = create_empty_pool
      pool.add_connection(site, conn1)
      pool.add_connection(site, conn2)

      expect(pool.connection_count).to eq(2)
    end

    it 'adds the connection to a pool with a connection for a different site' do
      connection = create_connection(site)

      pool = create_empty_pool
      pool.add_connection(site, connection)
      pool.add_connection(github_site, connection)

      expect(pool.connection_count).to eq(2)
    end
  end

  context 'when closing the pool' do
    it 'closes all cached connections' do
      connection = create_connection(site)
      connection.expects(:close)

      pool = create_pool_with_connection(site, connection)
      pool.close
    end

    it 'clears the pool' do
      connection = create_connection(site)
      connection.stubs(:close)

      pool = create_pool_with_connection(site, connection)
      pool.close

      expect(pool.connection_count).to eq(0)
    end
  end
end
