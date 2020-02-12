require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/connection'

describe Puppet::Network::HTTP::NoCachePool do
  let(:site) { Puppet::Network::HTTP::Site.new('https', 'rubygems.org', 443) }
  let(:verifier) { double('verifier', :setup_connection => nil) }

  it 'yields a started connection' do
    http  = double('http', start: nil, finish: nil, started?: true)

    factory = Puppet::Network::HTTP::Factory.new
    allow(factory).to receive(:create_connection).and_return(http)
    pool = Puppet::Network::HTTP::NoCachePool.new(factory)

    expect { |b|
      pool.with_connection(site, verifier, &b)
    }.to yield_with_args(http)
  end

  it 'yields a new connection each time' do
    http1  = double('http1', start: nil, finish: nil, started?: true)
    http2  = double('http2', start: nil, finish: nil, started?: true)

    factory = Puppet::Network::HTTP::Factory.new
    allow(factory).to receive(:create_connection).and_return(http1, http2)
    pool = Puppet::Network::HTTP::NoCachePool.new(factory)

    expect { |b|
      pool.with_connection(site, verifier, &b)
    }.to yield_with_args(http1)

    expect { |b|
      pool.with_connection(site, verifier, &b)
    }.to yield_with_args(http2)
  end

  it 'has a close method' do
    Puppet::Network::HTTP::NoCachePool.new.close
  end
end
