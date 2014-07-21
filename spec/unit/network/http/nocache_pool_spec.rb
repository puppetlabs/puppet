#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/connection'

describe Puppet::Network::HTTP::NoCachePool do
  it 'returns a new connection' do
    http = stub('http')
    verify = stub('verify', :setup_connection => nil)

    site = Puppet::Network::HTTP::Site.new('https', 'rubygems.org', 443)
    pool = Puppet::Network::HTTP::NoCachePool.new
    pool.factory.expects(:create_connection).with(site).returns(http)

    conn = Puppet::Network::HTTP::Connection.new(site.host, site.port, :use_ssl => site.use_ssl?, :verify => verify)

    yielded_http = nil
    pool.with_connection(conn) { |h| yielded_http = h }

    expect(yielded_http).to eq(http)
  end

  it 'has a close method' do
    Puppet::Network::HTTP::NoCachePool.new.close
  end
end
