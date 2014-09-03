#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/connection'

describe Puppet::Network::HTTP::NoCachePool do
  let(:site) { Puppet::Network::HTTP::Site.new('https', 'rubygems.org', 443) }
  let(:verify) { stub('verify', :setup_connection => nil) }

  it 'yields a connection' do
    http  = stub('http')

    factory = Puppet::Network::HTTP::Factory.new
    factory.stubs(:create_connection).returns(http)
    pool = Puppet::Network::HTTP::NoCachePool.new(factory)

    expect { |b|
      pool.with_connection(site, verify, &b)
    }.to yield_with_args(http)
  end

  it 'yields a new connection each time' do
    http1  = stub('http1')
    http2  = stub('http2')

    factory = Puppet::Network::HTTP::Factory.new
    factory.stubs(:create_connection).returns(http1).then.returns(http2)
    pool = Puppet::Network::HTTP::NoCachePool.new(factory)

    expect { |b|
      pool.with_connection(site, verify, &b)
    }.to yield_with_args(http1)

    expect { |b|
      pool.with_connection(site, verify, &b)
    }.to yield_with_args(http2)
  end

  it 'has a close method' do
    Puppet::Network::HTTP::NoCachePool.new.close
  end
end
